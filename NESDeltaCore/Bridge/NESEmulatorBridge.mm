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

// C++
#include <fstream>

static bool NST_CALLBACK AudioLock(void *context, Nes::Api::Sound::Output& audioOutput);
static void NST_CALLBACK AudioUnlock(void *context, Nes::Api::Sound::Output& audioOutput);

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

@property (nonatomic, readonly) uint16_t *audioBuffer;
@property (nonatomic, readonly) NSLock *audioLock;
@property (nonatomic, readonly) NSInteger preferredAudioFrameLength;

@end

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
    
    
    /* Load Database */
    if (!self.database.IsLoaded())
    {
        NSURL *databaseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"NstDatabase" withExtension:@"xml"];
        
        std::ifstream databaseFileStream([databaseURL fileSystemRepresentation], std::ifstream::in | std::ifstream::binary);
        
        self.database.Load(databaseFileStream);
        self.database.Enable();
        
        databaseFileStream.close();
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
}

- (void)stop
{
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
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(NSString *)type
{
    return YES;
}

- (void)resetCheats
{
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
