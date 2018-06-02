//
//  NESEmulatorBridge.hpp
//  NESDeltaCore
//
//  Created by Riley Testut on 6/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

#ifndef NESEmulatorBridge_hpp
#define NESEmulatorBridge_hpp

#include <stdio.h>

extern "C"
{
    typedef void (*BufferCallback)(char *buffer, int size);
    typedef void (*VoidCallback)(void);
    
    void NESInitialize(const char *databasePath);
    
    bool NESStartEmulation(const char *gamePath);
    void NESStopEmulation();
    
    void NESRunFrame();
    
    void NESActivateInput(int input);
    void NESDeactivateInput(int input);
    void NESResetInputs();
    
    void NESSaveSaveState(const char *saveStatePath);
    void NESLoadSaveState(const char *saveStatePath);
    
    void NESSaveGameSave(const char *gameSavePath);
    void NESLoadGameSave(const char *gameSavePath);
    
    bool NESAddCheatCode(const char *cheatCode);
    void NESResetCheats();
    
    void NESSetAudioCallback(BufferCallback audioCallback);
    void NESSetVideoCallback(BufferCallback videoCallback);
    void NESSetSaveCallback(VoidCallback saveCallback);
}

#endif /* NESEmulatorBridge_hpp */
