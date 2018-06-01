//
//  NESEmulatorBridge.m
//  NESDeltaCore
//
//  Created by Riley Testut on 2/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

#import "NESEmulatorBridge.h"
#include "NESEmulatorBridge.hpp"

// NESDeltaCore
#import <NESDeltaCore/NESDeltaCore.h>
#import <NESDeltaCore/NESDeltaCore-Swift.h>

static void NESAudioCallback(char *buffer, int size);
static void NESVideoCallback(char *buffer, int size);
static void NESSaveCallback();

NS_ASSUME_NONNULL_BEGIN

@interface NESEmulatorBridge ()

@property (nonatomic, copy, nullable, readwrite) NSURL *gameURL;

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
        NSURL *databaseURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"NstDatabase" withExtension:@"xml"];
        NESInitialize(databaseURL.fileSystemRepresentation);
        
        NESSetAudioCallback(NESAudioCallback);
        NESSetVideoCallback(NESVideoCallback);
        NESSetSaveCallback(NESSaveCallback);
    }
    
    return self;
}

#pragma mark - Emulation State -

- (void)startWithGameURL:(NSURL *)gameURL
{
    self.gameURL = gameURL;
    
    if (!NESStartEmulation(gameURL.fileSystemRepresentation))
    {
        NSLog(@"Error launching game at %@", gameURL);
    }
}

- (void)stop
{
    self.gameURL = nil;
    
    NESStopEmulation();
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
    NESRunFrame();
}

#pragma mark - Inputs -

- (void)activateInput:(NSInteger)input
{
    NESActivateInput((int)input);
}

- (void)deactivateInput:(NSInteger)input
{
    NESDeactivateInput((int)input);
}

- (void)resetInputs
{
    NESResetInputs();
}

#pragma mark - Save States -

- (void)saveSaveStateToURL:(NSURL *)url
{
    NESSaveSaveState(url.fileSystemRepresentation);
}

- (void)loadSaveStateFromURL:(NSURL *)url
{
    NESLoadSaveState(url.fileSystemRepresentation);
}

#pragma mark - Game Saves -

- (void)saveGameSaveToURL:(NSURL *)url
{
    NESSaveGameSave(url.fileSystemRepresentation);
}

- (void)loadGameSaveFromURL:(NSURL *)url
{
    NESLoadGameSave(url.fileSystemRepresentation);
}

#pragma mark - Cheats -

- (BOOL)addCheatCode:(NSString *)cheatCode type:(CheatType)type
{
    if (![type isEqualToString:CheatTypeGameGenie])
    {
        return NO;
    }

    BOOL result = NESAddCheatCode([cheatCode UTF8String]);
    return result;
}

- (void)resetCheats
{
    NESResetCheats();
}

- (void)updateCheats
{
}

@end

#pragma mark - Callbacks -

static void NESAudioCallback(char *buffer, int size)
{
    [[NESEmulatorBridge.sharedBridge.audioRenderer audioBuffer] writeBuffer:(uint8_t *)buffer size:size];
}

static void NESVideoCallback(char *buffer, int size)
{
    memcpy([NESEmulatorBridge.sharedBridge.videoRenderer videoBuffer], buffer, size);
}

static void NESSaveCallback()
{
    if (NESEmulatorBridge.sharedBridge.saveUpdateHandler != NULL)
    {
        NESEmulatorBridge.sharedBridge.saveUpdateHandler();
    }
}
