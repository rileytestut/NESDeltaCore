//
//  NESEmulatorBridge.swift
//  NESDeltaCore
//
//  Created by Riley Testut on 6/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import DeltaCore

let NESAudioCallback: @convention(c) (UnsafePointer<UInt8>, Int32) -> Void = { (buffer, size) in
    NESEmulatorBridge.shared.audioRenderer?.audioBuffer.write(buffer, size: Int(size))
}

let NESVideoCallback: @convention(c) (UnsafePointer<UInt8>, Int32) -> Void = { (buffer, size) in
    memcpy(NESEmulatorBridge.shared.videoRenderer?.videoBuffer, buffer, Int(size))
}

let NESSaveCallback: @convention(c) () -> Void = {
    NESEmulatorBridge.shared.saveUpdateHandler?()
}

public class NESEmulatorBridge : NSObject, EmulatorBridging
{
    public static let shared = NESEmulatorBridge()
    
    public private(set) var gameURL: URL?
    
    public var audioRenderer: AudioRendering?
    public var videoRenderer: VideoRendering?
    public var saveUpdateHandler: (() -> Void)?
    
    private override init()
    {
        let databaseURL = Bundle(for: type(of: self)).url(forResource: "NstDatabase", withExtension: "xml")!
        databaseURL.withUnsafeFileSystemRepresentation { NESInitialize($0!) }
        
        NESSetAudioCallback(NESAudioCallback)
        NESSetVideoCallback(NESVideoCallback)
        NESSetSaveCallback(NESSaveCallback)
    }
}

public extension NESEmulatorBridge
{
    func start(withGameURL gameURL: URL)
    {
        self.gameURL = gameURL
        
        if !gameURL.withUnsafeFileSystemRepresentation({ NESStartEmulation($0!) })
        {
            print("Error launching game at", gameURL)
        }
    }
    
    func stop()
    {
        self.gameURL = nil
        
        NESStopEmulation()
    }
    
    func pause()
    {
    }
    
    func resume()
    {
    }
    
    func runFrame()
    {
        NESRunFrame()
    }
    
    func activateInput(_ input: Int)
    {
        NESActivateInput(Int32(input))
    }
    
    func deactivateInput(_ input: Int)
    {
        NESDeactivateInput(Int32(input))
    }
    
    func resetInputs()
    {
        NESResetInputs()
    }
    
    func saveSaveState(to url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESSaveSaveState($0!) }
    }
    
    func loadSaveState(from url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESLoadSaveState($0!) }
    }
    
    func saveGameSave(to url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESSaveGameSave($0!) }
    }
    
    func loadGameSave(from url: URL)
    {
        url.withUnsafeFileSystemRepresentation { NESLoadGameSave($0!) }
    }
    
    func addCheatCode(_ cheatCode: String, type: CheatType) -> Bool
    {
        guard type == .gameGenie else { return false }
        
        let success = NESAddCheatCode(cheatCode)
        return success
    }
    
    func resetCheats()
    {
        NESResetCheats()
    }
    
    func updateCheats()
    {
    }
}
