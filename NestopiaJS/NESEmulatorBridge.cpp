//
//  NESEmulatorBridge.cpp
//  NESDeltaCore
//
//  Created by Riley Testut on 6/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

#include "NESEmulatorBridge.hpp"

// Nestopia
#include "NstBase.hpp"
#include "NstApiEmulator.hpp"
#include "NstApiMachine.hpp"
#include "NstApiCartridge.hpp"
#include "NstApiUser.hpp"
#include "NstApiInput.hpp"
#include "NstApiSound.hpp"
#include "NstApiVideo.hpp"
#include "NstApiCheats.hpp"

// C++
#include <iostream>
#include <fstream>

// Variables
Nes::Api::Emulator emulator;
Nes::Api::Sound::Output audioOutput;
Nes::Api::Video::Output videoOutput;
Nes::Api::Input::Controllers controllers;

Nes::Api::Machine machine(emulator);
Nes::Api::Cartridge::Database database(emulator);
Nes::Api::Input input(emulator);
Nes::Api::Sound audio(emulator);
Nes::Api::Video video(emulator);
Nes::Api::Cheats cheats(emulator);

VoidCallback saveCallback = NULL;
BufferCallback audioCallback = NULL;
BufferCallback videoCallback = NULL;

uint16_t audioBuffer[0x8000];
unsigned int preferredAudioFrameLength = 735;

uint8_t videoBuffer[Nes::Api::Video::Output::WIDTH * Nes::Api::Video::Output::HEIGHT * 2];

char *gameSaveSavePath = NULL;
char *gameSaveLoadPath = NULL;

bool gameLoaded = false;
char *gamePath = NULL;

static bool NST_CALLBACK AudioLock(void *context, Nes::Api::Sound::Output& audioOutput);
static void NST_CALLBACK AudioUnlock(void *context, Nes::Api::Sound::Output& audioOutput);
static bool NST_CALLBACK VideoLock(void *context, Nes::Api::Video::Output& videoOutput);
static void NST_CALLBACK VideoUnlock(void *context, Nes::Api::Video::Output& videoOutput);
static void NST_CALLBACK FileIO(void *context, Nes::Api::User::File& file);

#pragma mark - Initialization/Deallocation -

void NESInitialize(const char *databasePath)
{
    /* Load Database */
    std::ifstream databaseFileStream(databasePath, std::ifstream::in | std::ifstream::binary);
    database.Load(databaseFileStream);
    database.Enable();
    
    /* Prepare Callbacks */
    Nes::Api::Sound::Output::lockCallback.Set(AudioLock, NULL);
    Nes::Api::Sound::Output::unlockCallback.Set(AudioUnlock, NULL);
    Nes::Api::Video::Output::lockCallback.Set(VideoLock, NULL);
    Nes::Api::Video::Output::unlockCallback.Set(VideoUnlock, NULL);
    Nes::Api::User::fileIoCallback.Set(FileIO, NULL);
}

#pragma mark - Emulation -

bool NESStartEmulation(const char *gameFilepath)
{
    gamePath = strdup(gameFilepath);
    
    /* Load Game */
    std::ifstream gameFileStream(gameFilepath, std::ios::in | std::ios::binary);
    
    Nes::Result result = machine.Load(gameFileStream, Nes::Api::Machine::FAVORED_NES_NTSC);
    if (NES_FAILED(result))
    {
        std::cout << "Failed to launch game at " << gameFilepath << ". Error Code: " << result << std::endl;
        return false;
    }
    
    
    /* Prepare Audio */
    audio.SetSampleBits(16);
    audio.SetSampleRate(44100);
    audio.SetVolume(Nes::Api::Sound::ALL_CHANNELS, 85);
    audio.SetSpeaker(Nes::Api::Sound::SPEAKER_MONO);
    
    audioOutput.samples[0] = audioBuffer;
    audioOutput.length[0] = preferredAudioFrameLength;
    audioOutput.samples[1] = NULL;
    audioOutput.length[1] = 0;
    
    
    /* Prepare Video */
    video.EnableUnlimSprites(true);
    
    videoOutput.pixels = videoBuffer;
    videoOutput.pitch = Nes::Api::Video::Output::WIDTH * 2;
    
    Nes::Api::Video::RenderState renderState;
    renderState.filter = Nes::Api::Video::RenderState::FILTER_NONE;
    renderState.width = Nes::Api::Video::Output::WIDTH;
    renderState.height = Nes::Api::Video::Output::HEIGHT;
    
    // RGB 565
    renderState.bits.count = 16;
    renderState.bits.mask.r = 0xF800;
    renderState.bits.mask.g = 0x07E0;
    renderState.bits.mask.b = 0x001F;
    
    if (NES_FAILED(video.SetRenderState(renderState)))
    {
        return false;
    }
    
    
    /* Prepare Inputs */
    input.ConnectController(0, Nes::Api::Input::PAD1);
    
    
    /* Start Emulation */
    machine.Power(true);
    machine.SetMode(machine.GetDesiredMode());
    
    gameLoaded = true;
    
    return true;
}

void NESStopEmulation()
{
    gamePath = NULL;
    gameLoaded = false;
    
    machine.Unload();
}

#pragma mark - Game Loop -

void NESRunFrame()
{
    emulator.Execute(&videoOutput, &audioOutput, &controllers);
}

#pragma mark - Inputs -

void NESActivateInput(int input)
{
    controllers.pad[0].buttons |= input;
}

void NESDeactivateInput(int input)
{
    controllers.pad[0].buttons &= ~input;
}

void NESResetInputs()
{
    controllers.pad[0].buttons = 0;
}

#pragma mark - Save States -

void NESSaveSaveState(const char *saveStateFilepath)
{
    std::ofstream fileStream(saveStateFilepath, std::ifstream::out | std::ifstream::binary);
    machine.SaveState(fileStream);
}

void NESLoadSaveState(const char *saveStateFilepath)
{
    std::ifstream fileStream(saveStateFilepath, std::ifstream::in | std::ifstream::binary);
    machine.LoadState(fileStream);
}

#pragma mark - Game Saves -

void NESSaveGameSave(const char *gameSavePath)
{
    gameSaveSavePath = strdup(gameSavePath);
    
    std::string saveStatePath(gameSavePath);
    saveStatePath += ".temp";
    
    // Create tempoary save state.
    NESSaveSaveState(saveStatePath.c_str());
    
    // Unload cartridge, which forces emulator to save game.
    machine.Unload();
    
    // Check after machine.Unload but before restarting to make sure we aren't starting emulator when no game is loaded.
    if (!gameLoaded)
    {
        return;
    }
    
    // Restart emulation.
    NESStartEmulation(gamePath);
    
    // Load previous save save.
    NESLoadSaveState(saveStatePath.c_str());
    
    // Delete temporary save state.
    remove(saveStatePath.c_str());
}

void NESLoadGameSave(const char *gameSavePath)
{
    gameSaveLoadPath = strdup(gameSavePath);
    
    // Restart emulation so FileIO callback is called.
    NESStartEmulation(gamePath);
}

#pragma mark - Cheats -

bool NESAddCheatCode(const char *cheatCode)
{
    Nes::Api::Cheats::Code code;
    
    if (NES_FAILED(Nes::Api::Cheats::GameGenieDecode(cheatCode, code)))
    {
        return false;
    }
    
    if (NES_FAILED(cheats.SetCode(code)))
    {
        return false;
    }
    
    return true;
}

void NESResetCheats()
{
    cheats.ClearCodes();
}

#pragma mark - Callbacks -

void NESSetAudioCallback(BufferCallback callback)
{
    audioCallback = callback;
}

void NESSetVideoCallback(BufferCallback callback)
{
    videoCallback = callback;
}

void NESSetSaveCallback(VoidCallback callback)
{
    saveCallback = callback;
}

static bool NST_CALLBACK AudioLock(void *context, Nes::Api::Sound::Output& audioOutput)
{
    return true;
}

static void NST_CALLBACK AudioUnlock(void *context, Nes::Api::Sound::Output& audioOutput)
{
    if (audioCallback == NULL)
    {
        return;
    }
    
    audioCallback((unsigned char *)audioBuffer, preferredAudioFrameLength * sizeof(int16_t));
}

static bool NST_CALLBACK VideoLock(void *context, Nes::Api::Video::Output& videoOutput)
{
    return true;
}

static void NST_CALLBACK VideoUnlock(void *context, Nes::Api::Video::Output& videoOutput)
{
    if (videoCallback == NULL)
    {
        return;
    }
    
    (*videoCallback)((const unsigned char *)videoBuffer, Nes::Api::Video::Output::WIDTH * Nes::Api::Video::Output::HEIGHT * 2);
}

static void NST_CALLBACK FileIO(void *context, Nes::Api::User::File& file)
{
    switch (file.GetAction())
    {
        case Nes::Api::User::File::LOAD_BATTERY:
        case Nes::Api::User::File::LOAD_EEPROM:
        {
            if (gameSaveLoadPath == NULL)
            {
                return;
            }
            
            std::ifstream fileStream(gameSaveLoadPath);
            file.SetContent(fileStream);
            
            gameSaveLoadPath = NULL;
            
            break;
        }
            
        case Nes::Api::User::File::SAVE_BATTERY:
        case Nes::Api::User::File::SAVE_EEPROM:
        {
            if (gameSaveSavePath == NULL)
            {
                if (saveCallback != NULL)
                {
                    saveCallback();
                }
                
                return;
            }
            
            std::ofstream fileStream(gameSaveSavePath);
            file.GetContent(fileStream);
            
            gameSaveSavePath = NULL;
            
            break;
        }
            
        default:
            break;
    }
}
