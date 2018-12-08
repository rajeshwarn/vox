import UIKit
import Socket
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var label: UILabel!
    let ae = AVAudioEngine()
    let player = AVAudioPlayerNode()
    var mixer: AVAudioMixerNode!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var p = SinePlayer()
        
        //Prevent iOS from sleeping, helps reduce audio lag
        UIApplication.shared.isIdleTimerDisabled = true
        
        //Enable background audio, also had to enable audio background capabilities in project settings
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback, with: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        
        //Setup audio engine
        mixer = ae.mainMixerNode
        ae.attach(player)
        ae.connect(player, to: mixer, format: player.outputFormat(forBus: 0))
        do { try ae.start() } catch {}
        self.player.play()
        
        //Setup up tcp server on socket 8080, big buffer size is appropriate, keep reading data while connection open
        //Do in background thread (userInteractive) so app won't crash for taking too long to start up
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let mySocket = try Socket.create()
                mySocket.readBufferSize = 60000
                try mySocket.listen(on: 8080)
                try mySocket.acceptConnection()
                self.setLabel("Connected")
                
                while !mySocket.remoteConnectionClosed {
                    let data = NSMutableData()
                    
                    if try mySocket.read(into: data) > 0 {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let buffer = self.toPCMBuffer(data)
                            self.player.scheduleBuffer(buffer, completionHandler: nil)
                        }
                    }
                }
                
                mySocket.close()
            } catch {}
            self.setLabel("Done")
        }
    }
    
    func toPCMBuffer(_ data: NSData) -> AVAudioPCMBuffer {
        //PCM, float 32, 44100, 2 channels, not interleaved
        let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!
        let PCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(data.length) / audioFormat.streamDescription.pointee.mBytesPerFrame)!
        PCMBuffer.frameLength = PCMBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(PCMBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return PCMBuffer
    }
    
    func enableLogging() {
        let allPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = allPaths.first!
        let pathForLog = documentsDirectory + "/yourFile.txt"
        
        do { try FileManager.default.removeItem(atPath: pathForLog) } catch {}
        freopen(pathForLog.cString(using: String.Encoding.ascii)!, "a+", stderr)
    }
    
    func setLabel(_ text: String) {
        DispatchQueue.main.async {
            self.label.text = text
        }
    }
    
    /*
     //Working setups
     //if c != 0 {
     let buffer = toPCMBuffer(data)
     NSLog("%i", buffer.frameLength)
     
     
     //DispatchQueue.global(qos: .userInteractive).async {
     self.player.scheduleBuffer(buffer, at: nil, options: AVAudioPlayerNodeBufferOptions.init(rawValue: 0), completionHandler: nil)
     //self.player.prepare(withFrameCount: buffer.frameLength)
     //}
     
     player.play()
     usleep(2000000)
     player.stop()
     player.reset()
     //break
     //}
     
     DispatchQueue.global(qos: .userInteractive).async {
     self.player.scheduleBuffer(buffer, at: nil, options: .interruptsAtLoop, completionHandler: nil)
     self.player.prepare(withFrameCount: buffer.frameLength)
     }
     
     player.play()
     Thread.sleep(forTimeInterval: 0.1)
     player.stop()
     player.reset()
     NSLog("did it")
     
     
     //Write to file
     let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
     let fileUrl = url.appendingPathComponent("sound")
     try self.totalData.write(to: fileUrl)
     
     //bytes to buffer method 2
     func bytesToAudioBuffer(_ data: Data) -> AVAudioPCMBuffer {
     let fmt = AVAudioFormat(commonFormat: .pcmFormatInt32, sampleRate: 44100, channels: 2, interleaved: true)!
     let frameLength = UInt32(data.count) / fmt.streamDescription.pointee.mBytesPerFrame
     
     let audioBuffer = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frameLength)!
     audioBuffer.frameLength = frameLength
     
     let bufPtr = audioBuffer.int32ChannelData![0]
     
     data.withUnsafeBytes { ptr in
     bufPtr.initialize(from: ptr, count: data.count)
     }
     
     return audioBuffer
     }
     
     //For debugging
     let allPaths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
     let documentsDirectory = allPaths.first!
     let pathForLog = documentsDirectory + "/yourFile.txt"
     
     do { try FileManager.default.removeItem(atPath: pathForLog) } catch {}
     freopen(pathForLog.cString(using: String.Encoding.ascii)!, "a+", stderr)
    
    var outputQueue: AudioQueueRef?
     var buffer: AudioQueueBufferRef?
     var stream: AudioFileStreamID?
     
     var format = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatLinearPCM, mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
     
     AudioQueueNewOutput(&format, { (userData, audioQueue, audioBuffer) -> Void in
     AudioFile
     AudioQueueEnqueueBuffer(audioQueue, audioBuffer, 0, nil)
     }, nil, nil, nil, 0, &outputQueue)
     
     AudioQueueAllocateBuffer(outputQueue!, 4, &buffer)
     AudioQueueEnqueueBuffer(outputQueue!, buffer!, 0, nil)
     
     AudioFileStreamOpen(nil,{ (a,b,c,d)  -> Void in }, { (a,b,c,d,e)  -> Void in }, kAudioFileWAVEType, &stream)
    
     var stream: AudioFileStreamID?
     var res = AudioFileStreamOpen(observer, { (obs,b,c,d)  -> Void in }, { (obs, numBytes, numPacks, data, packDescs)  -> Void in
     let mySelf = Unmanaged<ViewController>.fromOpaque(obs).takeUnretainedValue()
     mySelf.total += Int(numBytes)
     }, 0, &stream)
     NSLog(String(describing: res))
    
     //let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    
     var descr = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsSignedInteger, mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
     var aQueue: AudioQueueRef?
     var buffer: AudioQueueBufferRef?
     
     print(AudioQueueNewOutput(&descr, { (obs, queue, buffer) in
     
     AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
     }, observer, CFRunLoopGetMain(), nil, 0, &aQueue))
     
     AudioQueueAllocateBuffer(aQueue!, 4, &buffer)
     AudioQueueEnqueueBuffer(aQueue!, buffer!, 0, nil)
     AudioQueueStart(aQueue!, nil)*/

}

