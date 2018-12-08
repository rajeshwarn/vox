import AVFoundation

/**************
 
 I used this to figure out how AVAudioEngine works, I left it in
 because it seems helpful, but it is not necessary to build ettan
 
***************/

class SinePlayer{
    var ae:AVAudioEngine!
    var player:AVAudioPlayerNode!
    var mixer:AVAudioMixerNode!
    var buffer:AVAudioPCMBuffer!
    
    init() {
        // initialize objects
        ae = AVAudioEngine()
        player = AVAudioPlayerNode()
        mixer = ae.mainMixerNode;
        buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0), frameCapacity: 100)
        buffer.frameLength = 100
        
        // generate sine wave
        var sr:Float = Float(mixer.outputFormat(forBus: 0).sampleRate)
        var n_channels = mixer.outputFormat(forBus: 0).channelCount
        
        var i = 0
        while i < Int(buffer.frameLength) {
            var val = sinf(441.0*Float(i)*2*Float(Double.pi)/sr)
            buffer.floatChannelData?.pointee[i] = val * 0.5
            i+=Int(n_channels)
        }
        
        // setup audio engine
        ae.attach(player)
        ae.connect(player, to: mixer, format: player.outputFormat(forBus: 0))
        do { try ae.start() } catch { print("nope") }
        
        // play player and buffer
        player.play()
        player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
    }
    
}
