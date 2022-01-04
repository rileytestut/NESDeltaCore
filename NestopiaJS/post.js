function NESPrepareCore()
{
    _NESInitialize('NstDatabase.xml');
    
    var videoCallback = addFunction(function(buffer, size) {
      var typedArray = Module.HEAPU16.subarray(buffer/2, buffer/2 + size/2);
      var string = String.fromCharCode.apply(null, typedArray);
      window.webkit.messageHandlers.DLTAEmulatorBridge.postMessage({'type': 'video', 'data': string});
    });

    _NESSetVideoCallback(videoCallback);

    var audioCallback = addFunction(function(buffer, size) {
      var typedArray = Module.HEAPU8.subarray(buffer, buffer + size);
      var array = Array.from(typedArray);
      window.webkit.messageHandlers.DLTAEmulatorBridge.postMessage({'type': 'audio', 'data': array});
    });

    _NESSetAudioCallback(audioCallback);

    var saveCallback = addFunction(function() {
      window.webkit.messageHandlers.DLTAEmulatorBridge.postMessage({'type': 'save'});
    });

    _NESSetSaveCallback(saveCallback);

    window.webkit.messageHandlers.DLTAEmulatorBridge.postMessage({'type': 'ready'});
}
