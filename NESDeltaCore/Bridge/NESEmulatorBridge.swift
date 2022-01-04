//
//  NESEmulatorBridge.swift
//  NESDeltaCore
//
//  Created by Riley Testut on 6/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import DeltaCore

#if NATIVE
import NESBridge
#endif

class NESEmulatorBridge: AdaptableDeltaBridge
{
    public static let shared = NESEmulatorBridge()
    
    private var isDatabasePrepared = false
    
    override var adapter: EmulatorBridging {
#if !NATIVE
        let scriptURL = Bundle.module.url(forResource: "nestopia", withExtension: "html")!
        
        let adapter = JSCoreAdapter(prefix: "NES", fileURL: scriptURL)
        adapter.emulatorCore = self.emulatorCore
        return adapter
#else
        return NativeCoreAdapter(
            frameDuration: NESFrameDuration,
            start: NESStartEmulation,
            stop: NESStopEmulation,
            pause: {},
            resume: {},
            runFrame: NESRunFrame,
            activateInput: NESActivateInput,
            deactivateInput: NESDeactivateInput,
            resetInputs: NESResetInputs,
            saveSaveState: NESSaveSaveState,
            loadSaveState: NESLoadSaveState,
            saveGameSave: NESSaveGameSave,
            loadGameSave: NESLoadGameSave,
            addCheatCode: NESAddCheatCode,
            resetCheats: NESResetCheats,
            updateCheats: {},
            setAudioCallback: NESSetAudioCallback,
            setVideoCallback: NESSetVideoCallback,
            setSaveCallback: NESSetSaveCallback)
#endif
    }
    
    override func start(withGameURL gameURL: URL)
    {
#if NATIVE
        if !self.isDatabasePrepared
        {
            let databaseURL = Bundle.module.url(forResource: "NstDatabase", withExtension: "xml")!
            databaseURL.withUnsafeFileSystemRepresentation { NESInitialize($0!) }
            
            self.isDatabasePrepared = true
        }
#endif
        
        super.start(withGameURL: gameURL)
    }
}
