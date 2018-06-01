//
//  NESEmulatorBridge.m
//  NESDeltaCore
//
//  Created by Riley Testut on 2/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

#import "NESEmulatorBridge.h"

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
#include <fstream>

// NESDeltaCore
#import <NESDeltaCore/NESDeltaCore.h>
#import <NESDeltaCore/NESDeltaCore-Swift.h>

static bool NST_CALLBACK AudioLock(void *context, Nes::Api::Sound::Output& audioOutput);
static void NST_CALLBACK AudioUnlock(void *context, Nes::Api::Sound::Output& audioOutput);
static void NST_CALLBACK FileIO(void *context, Nes::Api::User::File& file);

NS_ASSUME_NONNULL_BEGIN

@interface NESEmulatorBridge ()

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

@property (nonatomic, assign, readonly) Nes::Api::Emulator *emulator;
@property (nonatomic, assign, readonly) Nes::Api::Sound::Output *audioOutput;
@property (nonatomic, assign, readonly) Nes::Api::Video::Output *videoOutput;
@property (nonatomic, assign, readonly) Nes::Api::Input::Controllers *controllers;

@property (nonatomic, readonly) Nes::Api::Machine machine;
@property (nonatomic, readonly) Nes::Api::Cartridge::Database database;
@property (nonatomic, readonly) Nes::Api::Input input;
@property (nonatomic, readonly) Nes::Api::Sound audio;
@property (nonatomic, readonly) Nes::Api::Video video;
@property (nonatomic, readonly) Nes::Api::Cheats cheats;

@property (nonatomic, readonly) uint16_t *audioBuffer;
@property (nonatomic, readonly) NSLock *audioLock;
@property (nonatomic, readonly) NSInteger preferredAudioFrameLength;

@property (nullable, nonatomic, copy) NSURL *gameSaveSaveURL;
@property (nullable, nonatomic, copy) NSURL *gameSaveLoadURL;

@property (nonatomic, getter=isGameLoaded) BOOL gameLoaded;

@end

NS_ASSUME_NONNULL_END


@implementation NESEmulatorBridge
@synthesize audioRenderer = _audioRenderer;
@synthesize videoRenderer = _videoRenderer;
@synthesize saveUpdateHandler = _saveUpdateHandler;

+ (instancetype)sharedBridge
{
    static NESEmulatorBridge *_emulatorBridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _emulatorBridge = [[self alloc] init];
    });
    
    return _emulatorBridge;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _emulator = new Nes::Api::Emulator();
        
        _audioOutput = new Nes::Api::Sound::Output();
        _videoOutput = new Nes::Api::Video::Output();
        
        _controllers = new Nes::Api::Input::Controllers();
        
        _audioBuffer = (uint16_t *)malloc(0x8000);
        _audioLock = [[NSLock alloc] init];
        _preferredAudioFrameLength = 735;
    }
    
    return self;
}

- (void)dealloc
{
    delete _emulator;
    delete _audioOutput;
    delete _videoOutput;
    delete _controllers;
    delete [] _audioBuffer;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    /* Prepare Callbacks */
    Nes::Api::Sound::Output::lockCallback.Set(AudioLock, NULL);
    Nes::Api::Sound::Output::unlockCallback.Set(AudioUnlock, NULL);
    Nes::Api::User::fileIoCallback.Set(FileIO, NULL);
    
    
    /* Load Database */
    if (!self.database.IsLoaded())
    {
        NSURL *databaseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"NstDatabase" withExtension:@"xml"];
        
        std::ifstream databaseFileStream([databaseURL fileSystemRepresentation], std::ifstream::in | std::ifstream::binary);
        self.database.Load(databaseFileStream);
        
        self.database.Enable();
    }
    
    
    /* Load Game */
    std::ifstream gameFileStream([self.gameURL fileSystemRepresentation], std::ios::in | std::ios::binary);
    
    Nes::Result result = self.machine.Load(gameFileStream, Nes::Api::Machine::FAVORED_NES_NTSC);
    if (NES_FAILED(result))
    {
        NSLog(@"Failed to launch game at %@. Error Code: %@", self.gameURL, @(result));
        return;
    }
    
    
    /* Prepare Audio */
    self.audio.SetSampleBits(16);
    self.audio.SetSampleRate(44100);
    self.audio.SetVolume(Nes::Api::Sound::ALL_CHANNELS, 85);
    self.audio.SetSpeaker(Nes::Api::Sound::SPEAKER_MONO);
    
    self.audioOutput->samples[0] = self.audioBuffer;
    self.audioOutput->length[0] = (unsigned int)self.preferredAudioFrameLength;
    self.audioOutput->samples[1] = NULL;
    self.audioOutput->length[1] = 0;
    
    
    /* Prepare Video */
    self.video.EnableUnlimSprites(true);
    
    self.videoOutput->pixels = [[[NESEmulatorBridge sharedBridge] videoRenderer] videoBuffer];
    self.videoOutput->pitch = Nes::Api::Video::Output::WIDTH * 2;
    
    Nes::Api::Video::RenderState renderState;
    renderState.filter = Nes::Api::Video::RenderState::FILTER_NONE;
    renderState.width = Nes::Api::Video::Output::WIDTH;
    renderState.height = Nes::Api::Video::Output::HEIGHT;
    
    // RGB 565
    renderState.bits.count = 16;
    renderState.bits.mask.r = 0xF800;
    renderState.bits.mask.g = 0x07E0;
    renderState.bits.mask.b = 0x001F;
    
    if (NES_FAILED(self.video.SetRenderState(renderState)))
    {
        NSLog(@"Failed to set render state.");
        return;
    }
    
    
    /* Prepare Inputs */
    self.input.ConnectController(0, Nes::Api::Input::PAD1);
    
    
    /* Start Emulation */
    self.machine.Power(true);
    self.machine.SetMode(self.machine.GetDesiredMode());
    
    self.gameLoaded = YES;
}

- (void)stop
{
    self.gameLoaded = NO;
    self.gameURL = nil;
    
    self.machine.Unload();
}

- (void)pause
{
}

- (void)resume
{
}

#pragma mark - Game Loop -

- (void)runFrame
{
    self.emulator->Execute(self.videoOutput, self.audioOutput, self.controllers);
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input
{
    self.controllers->pad[0].buttons |= input;
}

- (void)deactivateInput:(NSInteger)input
{
    self.controllers->pad[0].buttons &= ~input;
}

- (void)resetInputs
{
    self.controllers->pad[0].buttons = 0;
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)url
{
    std::ofstream fileStream([url fileSystemRepresentation], std::ifstream::out | std::ifstream::binary);
    self.machine.SaveState(fileStream);
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
    std::ifstream fileStream([url fileSystemRepresentation], std::ifstream::in | std::ifstream::binary);
    self.machine.LoadState(fileStream);
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
    self.gameSaveSaveURL = url;
    
    NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
    NSString *uniqueIdentifier = [[NSProcessInfo processInfo] globallyUniqueString];
    
    // Create tempoary save state.
    NSURL *temporaryURL = [temporaryDirectoryURL URLByAppendingPathComponent:uniqueIdentifier];
    [self saveSaveStateToURL:temporaryURL];
    
    // Unload cartridge, which forces emulator to save game.
    self.machine.Unload();
    
    // Check after self.machine.Unload but before restarting to make sure we aren't starting emulator when no game is loaded.
    if (![self isGameLoaded])
    {
        return;
    }
    
    // Restart emulation.
    [self startWithGameURL:self.gameURL];
    
    // Load previous save save.
    [self loadSaveStateFromURL:temporaryURL];
    
    // Delete temporary save state.
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:temporaryURL error:&error])
    {
        NSLog(@"Error deleting temporary save state. %@", error);
    }
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
    self.gameSaveLoadURL = url;
    
    // Restart emulation so FileIO callback is called.
    [self startWithGameURL:self.gameURL];
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(CheatType)type
{
    if (![type isEqualToString:CheatTypeGameGenie])
    {
        return NO;
    }
    
    Nes::Api::Cheats::Code code;
    
    if (NES_FAILED(Nes::Api::Cheats::GameGenieDecode([cheatCode UTF8String], code)))
    {
        return NO;
    }
    
    if (NES_FAILED(self.cheats.SetCode(code)))
    {
        return NO;
    }
    
    return YES;
}

- (void)resetCheats
{
    self.cheats.ClearCodes();
}

- (void)updateCheats
{
}

#pragma mark - Getters/Setters -

- (Nes::Api::Machine)machine
{
    return Nes::Api::Machine(*self.emulator);
}

- (Nes::Api::Cartridge::Database)database
{
    return Nes::Api::Cartridge::Database(*self.emulator);
}

- (Nes::Api::Input)input
{
    return Nes::Api::Input(*self.emulator);
}

- (Nes::Api::Sound)audio
{
    return Nes::Api::Sound(*self.emulator);
}

- (Nes::Api::Video)video
{
    return Nes::Api::Video(*self.emulator);
}

- (Nes::Api::Cheats)cheats
{
    return Nes::Api::Cheats(*self.emulator);
}

@end

#pragma mark - Callbacks -

static bool NST_CALLBACK AudioLock(void *context, Nes::Api::Sound::Output& audioOutput)
{
    return [NESEmulatorBridge.sharedBridge.audioLock tryLock];
}

static void NST_CALLBACK AudioUnlock(void *context, Nes::Api::Sound::Output& audioOutput)
{
    [[NESEmulatorBridge.sharedBridge.audioRenderer audioBuffer] writeBuffer:(uint8_t *)audioOutput.samples[0] size:NESEmulatorBridge.sharedBridge.preferredAudioFrameLength * sizeof(uint16_t)];
    
    [NESEmulatorBridge.sharedBridge.audioLock unlock];
}

static void NST_CALLBACK FileIO(void *context, Nes::Api::User::File& file)
{
    @autoreleasepool
    {
        switch (file.GetAction())
        {
            case Nes::Api::User::File::LOAD_BATTERY:
            case Nes::Api::User::File::LOAD_EEPROM:
            {
                if (NESEmulatorBridge.sharedBridge.gameSaveLoadURL == nil)
                {
                    return;
                }

                NSData *data = [NSData dataWithContentsOfURL:NESEmulatorBridge.sharedBridge.gameSaveLoadURL];
                if (data == nil)
                {
                    return;
                }
                
                file.SetContent(data.bytes, data.length);
                
                NESEmulatorBridge.sharedBridge.gameSaveLoadURL = nil;
                
                break;
            }
                
            case Nes::Api::User::File::SAVE_BATTERY:
            case Nes::Api::User::File::SAVE_EEPROM:
            {
                if (NESEmulatorBridge.sharedBridge.gameSaveSaveURL == nil)
                {
                    if (NESEmulatorBridge.sharedBridge.saveUpdateHandler != nil)
                    {
                        NESEmulatorBridge.sharedBridge.saveUpdateHandler();
                    }
                    
                    return;
                }
                
                const void *bytes = NULL;
                unsigned long length = 0;
                
                file.GetContent(bytes, length);
                
                NSData *data = [NSData dataWithBytes:bytes length:length];
                if (data == nil)
                {
                    return;
                }
                
                [data writeToURL:NESEmulatorBridge.sharedBridge.gameSaveSaveURL atomically:YES];
                
                NESEmulatorBridge.sharedBridge.gameSaveSaveURL = nil;
                
                break;
            }
                
            default: break;
        }
    }
}
