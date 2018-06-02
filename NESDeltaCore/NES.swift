//
//  NES.swift
//  NESDeltaCore
//
//  Created by Riley Testut on 2/25/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import AVFoundation

import DeltaCore

public extension GameType
{
    public static let nes = GameType("com.rileytestut.delta.game.nes")
}

public extension CheatType
{
    public static let gameGenie = CheatType("GameGenie")
}

@objc public enum NESGameInput: Int, Input
{
    case up = 0x10
    case down = 0x20
    case left = 0x40
    case right = 0x80
    case a = 0x01
    case b = 0x02
    case start = 0x08
    case select = 0x04
    
    public var type: InputType {
        return .game(.nes)
    }
}

public struct NES: DeltaCoreProtocol
{
    public static let core = NES()
    
    public let bundleIdentifier = "com.rileytestut.NESDeltaCore"
    
    public let gameType = GameType.nes
    
    public let gameInputType: Input.Type = NESGameInput.self
    
    public let gameSaveFileExtension = "sav"
    
    public let frameDuration = (1.0 / 60.0)
    
    public let audioFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 44100, channels: 1, interleaved: true)!
    
    public let videoFormat = VideoFormat(pixelFormat: .rgb565, dimensions: CGSize(width: 256, height: 240))
    
    public let supportedCheatFormats: Set<CheatFormat> = {
        let gameGenieFormat = CheatFormat(name: NSLocalizedString("Game Genie", comment: ""), format: "XXXXXX", type: .gameGenie, allowedCodeCharacters: .letters)
        return [gameGenieFormat]
    }()
    
    public let emulatorBridge: EmulatorBridging = NESEmulatorBridge.shared
    
    private init()
    {
    }
}

