//
//  NESEmulatorBridge.swift
//  NESDeltaCore
//
//  Created by Riley Testut on 6/1/18.
//  Copyright © 2018 Riley Testut. All rights reserved.
//

import Foundation
import WebKit

#if FRAMEWORK
import DeltaCore
#endif

extension NESEmulatorBridge
{
    enum MessageType: String
    {
        case ready
        case audio
        case video
        case save
    }
}

extension RunLoop
{
    func run(until condition: () -> Bool)
    {
        while !condition()
        {
            self.run(mode: RunLoop.Mode.default, before: .distantFuture)
        }
    }
}

extension WKWebView
{
    @discardableResult func evaluateJavaScriptSynchronously(_ javaScriptString: String) throws -> Any?
    {
        var finished = false
        
        var finishedResult: Any?
        var finishedError: Error?
        
        func evaluate()
        {
            self.evaluateJavaScript(javaScriptString) { (result, error) in
                finishedResult = result
                finishedError = error
                
                finished = true
            }
            
            RunLoop.current.run(until: { finished })
        }
        
        if Thread.isMainThread
        {
            evaluate()
        }
        else
        {
            DispatchQueue.main.sync {
                evaluate()
            }
        }        
        
        if let error = finishedError
        {
            throw error
        }
        
        return finishedResult
    }
}

public class NESEmulatorBridge : NSObject, EmulatorBridging
{
    public static let shared = NESEmulatorBridge()
    
    public private(set) var gameURL: URL?
    
    public private(set) var frameDuration: TimeInterval = (1.0 / 60.0)
    
    public var audioRenderer: AudioRendering?
    public var videoRenderer: VideoRendering?
    public var saveUpdateHandler: (() -> Void)?
    
    public static var applicationWindow: UIWindow?
    
    private var webView: WKWebView!
    private var initialNavigation: WKNavigation?
    
    private var isReady = false
    
    private override init()
    {
        super.init()
        
        #if NATIVE
        
        let databaseURL = NES.core.resourceBundle.url(forResource: "NstDatabase", withExtension: "xml")!
        databaseURL.withUnsafeFileSystemRepresentation { NESInitialize($0!) }
        
        NESSetAudioCallback { (buffer, size) in
            NESEmulatorBridge.shared.audioRenderer?.audioBuffer.write(buffer, size: Int(size))
        }
        
        NESSetVideoCallback { (buffer, size) in
            memcpy(UnsafeMutableRawPointer(NESEmulatorBridge.shared.videoRenderer?.videoBuffer), buffer, Int(size))
        }
        
        NESSetSaveCallback {
            NESEmulatorBridge.shared.saveUpdateHandler?()
        }
        
        self.isReady = true
        
        #else
        
        if let window = UIApplication.delta_shared?.delegate?.window
        {
            NESEmulatorBridge.applicationWindow = window
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "NESEmulatorBridge")
        
        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.webView.navigationDelegate = self
        self.webView.isHidden = true
        NESEmulatorBridge.applicationWindow?.addSubview(self.webView)
        
        self.initialNavigation = self.webView.loadHTMLString("<!doctype html></html>", baseURL: nil)
        
        #endif
    }
}

extension NESEmulatorBridge: WKNavigationDelegate
{
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    {
        guard navigation == self.initialNavigation else { return }
        
        let scriptURL = NES.core.resourceBundle.url(forResource: "nestopia", withExtension: "js")!
        
        do
        {
            let scriptData = try Data(contentsOf: scriptURL)
            let script = String(data: scriptData, encoding: .utf8)!
            
            self.webView.evaluateJavaScript(script) { (result, error) in
                if let error = error
                {
                    print(error)
                }
            }
        }
        catch
        {
            print(error)
        }
        
        self.initialNavigation = nil
    }
}

extension NESEmulatorBridge: WKScriptMessageHandler
{
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage)
    {
        guard let payload = message.body as? [String: Any] else { return }
        
        guard let messageTypeString = payload["type"] as? String, let messageType = MessageType(rawValue: messageTypeString) else { return }
        
        switch messageType
        {
        case .ready: self.isReady = true
            
        case .audio:
            guard let bytes = payload["data"] as? [UInt8] else { return }
            self.audioRenderer?.audioBuffer.write(bytes, size: bytes.count)

        case .video:
            guard let string = payload["data"] as? String else { return }
            
            let array = Array(string.utf16)
            array.withUnsafeBytes { (pointer) in
                let bytes = pointer.bindMemory(to: UInt8.self)
                _ = memcpy(self.videoRenderer?.videoBuffer, bytes.baseAddress!, bytes.count)
            }
            
        case .save: self.saveUpdateHandler?()
        }
    }
}

private extension NESEmulatorBridge
{
    func importFile(at fileURL: URL, to path: String) throws
    {
        let data = try Data(contentsOf: fileURL)
        let bytes = data.map { $0 }
        
        let script = """
        var data = Uint8Array.from(\(bytes));
        FS.writeFile('\(path)', data);
        """
        
        try self.webView.evaluateJavaScriptSynchronously(script)
    }
    
    func exportFile(at path: String, to fileURL: URL) throws
    {
        let script = """
        var bytes = FS.readFile('\(path)');
        Array.from(bytes);
        """
        
        let bytes = try self.webView.evaluateJavaScriptSynchronously(script) as! [UInt8]
        
        let data = Data(bytes)
        try data.write(to: fileURL)
    }
}

public extension NESEmulatorBridge
{
    func start(withGameURL gameURL: URL)
    {
        if !self.isReady
        {
            RunLoop.current.run(until: { self.isReady })
        }
        
        self.gameURL = gameURL
        
        #if NATIVE
        
        gameURL.withUnsafeFileSystemRepresentation { _ = NESStartEmulation($0!) }
        
        self.frameDuration = NESFrameDuration()
        
        #else
        
        let path = gameURL.lastPathComponent
        
        do
        {
            try self.importFile(at: gameURL, to: path)
            
            let script = "Module.ccall('NESStartEmulation', null, ['string'], ['\(path)'])"
            let result = try self.webView.evaluateJavaScriptSynchronously(script) as! Bool
            
            guard result else {
                print("Error launching game at", gameURL)
                return
            }
            
            self.frameDuration = try self.webView.evaluateJavaScriptSynchronously("_NESFrameDuration()") as! TimeInterval
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func stop()
    {
        self.gameURL = nil
        
        #if NATIVE
        
        NESStopEmulation()
        
        #else
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_NESStopEmulation()")
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func pause()
    {
    }
    
    func resume()
    {
    }
    
    func runFrame(processVideo: Bool)
    {
        #if NATIVE
        
        NESRunFrame()
        
        #else
        
        DispatchQueue.main.async {
            self.webView.evaluateJavaScript("_NESRunFrame()") { (result, error) in
                if let error = error
                {
                    print(error)
                }
            }
        }
        
        #endif
        
        if processVideo
        {
            self.videoRenderer?.processFrame()
        }
    }
    
    func activateInput(_ input: Int, value: Double)
    {
        #if NATIVE
        
        NESActivateInput(Int32(input))
        
        #else
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_NESActivateInput(\(input))")
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func deactivateInput(_ input: Int)
    {
        #if NATIVE
        
        NESDeactivateInput(Int32(input))
        
        #else
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_NESDeactivateInput(\(input))")
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func resetInputs()
    {
        #if NATIVE
        
        NESResetInputs()
        
        #else
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_NESResetInputs()")
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func saveSaveState(to url: URL)
    {
        #if NATIVE
        
        url.withUnsafeFileSystemRepresentation { NESSaveSaveState($0!) }
        
        #else
        
        let path = url.lastPathComponent

        do
        {
            let script = "Module.ccall('NESSaveSaveState', null, ['string'], ['\(path)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
            
            try self.exportFile(at: path, to: url)
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func loadSaveState(from url: URL)
    {
        #if NATIVE
        
        url.withUnsafeFileSystemRepresentation { NESLoadSaveState($0!) }
        
        #else
        
        let path = url.lastPathComponent

        do
        {
            try self.importFile(at: url, to: path)

            let script = "Module.ccall('NESLoadSaveState', null, ['string'], ['\(path)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func saveGameSave(to url: URL)
    {
        #if NATIVE
        
        url.withUnsafeFileSystemRepresentation { NESSaveGameSave($0!) }
        
        #else
        
        let path = url.lastPathComponent

        do
        {
            let script = "Module.ccall('NESSaveGameSave', null, ['string'], ['\(path)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)

            try self.exportFile(at: path, to: url)
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func loadGameSave(from url: URL)
    {
        #if NATIVE
        
        url.withUnsafeFileSystemRepresentation { NESLoadGameSave($0!) }
        
        #else
        
        let path = url.lastPathComponent
        
        do
        {
            try self.importFile(at: url, to: path)

            let script = "Module.ccall('NESLoadGameSave', null, ['string'], ['\(path)'])"
            try self.webView.evaluateJavaScriptSynchronously(script)
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func addCheatCode(_ cheatCode: String, type: String) -> Bool
    {
        let cheatType = CheatType(type)
        guard cheatType == .gameGenie6 || cheatType == .gameGenie8 else { return false }

        let codes = cheatCode.split(separator: "\n")
        for code in codes
        {
            #if NATIVE
            if !code.withCString({ NESAddCheatCode($0) })
            {
                return false
            }
            #else
            do
            {
                let script = "Module.ccall('NESAddCheatCode', null, ['string'], ['\(code)'])"

                let success = try self.webView.evaluateJavaScriptSynchronously(script) as! Bool
                return success
            }
            catch
            {
                print(error)
            }
            #endif
        }
        
        return true
    }
    
    func resetCheats()
    {
        #if NATIVE
        
        NESResetCheats()
        
        #else
        
        do
        {
            try self.webView.evaluateJavaScriptSynchronously("_NESResetCheats()")
        }
        catch
        {
            print(error)
        }
        
        #endif
    }
    
    func updateCheats()
    {
    }
}
