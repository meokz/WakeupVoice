import Foundation

import UIKit
import Speech
import AVFoundation
import Pulsator
import AudioToolbox

extension String {
    func toKatakana() -> String {
        var str = ""
        
        for c in unicodeScalars {
            if c.value >= 0x3041 && c.value <= 0x3096 {
                str += String(describing: UnicodeScalar(c.value + 96)!)
            } else {
                str += String(c)
            }
        }
        
        return str
    }
    
    func toHiragana() -> String {
        var str = ""
        
        for c in unicodeScalars {
            if c.value >= 0x30A1 && c.value <= 0x30F6 {
                str += String(describing: UnicodeScalar(c.value - 96)!)
            } else {
                str += String(c)
            }
        }
        
        return str
    }
}

private func AudioQueueInputCallback(
    _ inUserData: UnsafeMutableRawPointer?,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef,
    inStartTime: UnsafePointer<AudioTimeStamp>,
    inNumberPacketDescriptions: UInt32,
    inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?)
{
    // Do nothing, because not recoding.
}

public class VoiceRecognizeViewController : UIViewController,
    SFSpeechRecognizerDelegate ,AVAudioPlayerDelegate {
    
    @IBOutlet weak var  textView: UILabel!
    @IBOutlet var recordButton : UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sourceView: UIImageView!
      
//    @IBOutlet weak var Volume1: UILabel!
//    @IBOutlet weak var Volume2: UILabel!
//    @IBOutlet weak var Volume3: UILabel!
//    @IBOutlet weak var Volume4: UILabel!
//    @IBOutlet weak var Volume5: UILabel!
//      
    @IBOutlet weak var volumeLabel : UILabel!
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    
    let checkButtonImage :UIImage? = UIImage(named:"check.png")

    var audioPlayer:AVAudioPlayer!
    
    var vol = 1.0
    
    var voiceRecognize : VoiceRecognizeModel = VoiceRecognizeModel()

    let pulsator = Pulsator()
    var queue: AudioQueueRef!
    
    var isVolumeInit : Bool = false
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false

        // 時間の設定
        timeDisplay()
        _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timeDisplay), userInfo: nil, repeats: true)

        volumeDisplay()
        _ = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(volumeDisplay), userInfo: nil, repeats: true)
        
        let text = "\"" + self.voiceRecognize.speechText + "\"";
        self.textView.text = text + "\nと言ってください"
        self.textView.numberOfLines = 2
        
        playSound()
        
        sourceView.layer.superlayer?.insertSublayer(pulsator, below: sourceView.layer)
        pulsator.numPulse = 3
        pulsator.radius = 125.0
        pulsator.backgroundColor = UIColor(red: 0.0, green: 0.635, blue: 1.00, alpha: 0.80).cgColor
        
//        Volume1.backgroundColor = UIColor.green
//        Volume2.backgroundColor = UIColor.green
//        Volume3.backgroundColor = UIColor.green
//        Volume4.backgroundColor = UIColor.green
//        Volume5.backgroundColor = UIColor.green
    }

    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        pulsator.start()
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                case .denied:
                    self.recordButton.isEnabled = false
//                    self.recordButton.setTitle("ユーザが音声認識を許可しませんでした", for: .disabled)
                case .restricted:
                    self.recordButton.isEnabled = false
//                    self.recordButton.setTitle("このデバイスでの音声認識は制限されています", for: .disabled)
                case .notDetermined:
                    self.recordButton.isEnabled = false
//                    self.recordButton.setTitle("音声認識はまだ許可されてsいません", for: .disabled)
                }
            }
        }
    
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.layoutIfNeeded()
        pulsator.position = sourceView.layer.position
    }

    
    private func startRecording() throws {
        // 現在のタスクを一旦キャンセル
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                let voice =  result.bestTranscription.formattedString
                self.textView.text = voice
                isFinal = result.isFinal
                //文字列と音声が一致した時
                if voice.toHiragana() == self.voiceRecognize.speechText.toHiragana() {
                    self.voiceRecognize.isRecognized = true;
                    self.voiceRecognize.speechText = voice;
                }
            }
            
            if error != nil || isFinal {
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.endRecognization()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        textView.text = "(認識中...)"
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
//            recordButton.setTitle("認識開始", for: [])
        } else {
            recordButton.isEnabled = false
//            recordButton.setTitle("認識できません", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if voiceRecognize.isRecognized && voiceRecognize.isVolume {
            // アラームリストを開く
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let recognizeVC = storyboard.instantiateViewController(withIdentifier: "Navigation") as? UINavigationController
            self.present(recognizeVC!, animated: true, completion: nil)
        } else {
            
            // 音声認識開始
            if (audioPlayer.isPlaying){
                audioPlayer.stop()
            }
            try! startRecording()
            startUpdatingVolume()
            recordButton.setTitle("認識中止", for: [])
        }
    }
    
    @IBAction func recordButtonReleased() {
        if audioEngine.isRunning {
            audioEngine.stop()
            stopUpdatingVolume()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("中止しています", for: .disabled)
        }
    }
    
    func timeDisplay(){
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.ReferenceType.local
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let date  = Date()
        let datestr = formatter.string(from :date)
        let  dateComponents = datestr.components(separatedBy: "-")
        let hour = dateComponents[3]
        let minute = dateComponents[4]
        timeLabel.text = hour + ":" + minute
        timeLabel.adjustsFontSizeToFitWidth = true
        textView.adjustsFontSizeToFitWidth = true
    }
    
    func volumeDisplay() {
        if isVolumeInit == false {
            return
        }
        
        var levelMeter = AudioQueueLevelMeterState()
        var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
        
        AudioQueueGetProperty(self.queue, kAudioQueueProperty_CurrentLevelMeterDB,
                              &levelMeter, &propertySize)
        
        // Show the audio channel's peak and average RMS power.
        self.volumeLabel.text = "".appendingFormat("%.2f", levelMeter.mPeakPower)
//        self.averageTextField.text = "".appendingFormat("%.2f", levelMeter.mAveragePower)
        
        if levelMeter.mPeakPower > voiceRecognize.volume {
            voiceRecognize.isVolume = true
        }
    }
    
    func endRecognization() {
        self.audioEngine.stop()
        self.stopUpdatingVolume()
        
        if voiceRecognize.isRecognized && voiceRecognize.isVolume {
            // 正解，音を止める
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            
            let text = "\"" + voiceRecognize.speechText + "\"";
            textView.text = text  + "と言いました"
          
            pulsator.stop()
            
            // チェックボタンの変更
            self.recordButton.setImage(self.checkButtonImage!, for: .normal)
        } else {
            // 不正解，音を再生
            vol += 10.0
            playSound()
            
            if !voiceRecognize.isRecognized && !voiceRecognize.isVolume {
                let text = "\"" + voiceRecognize.speechText + "\"";
                textView.text = "もっと大きな声で" + text  + "と言ってください"
            } else if !voiceRecognize.isRecognized {
                let text = "\"" + voiceRecognize.speechText + "\"";
                textView.text = text  + "と言ってください"
            } else if !voiceRecognize.isVolume {
                textView.text = "もっと大きな声で言ってください"
            }
        }
        
        recordButton.isEnabled = true
    }
    
    func playSound() {
        if audioPlayer != nil {
            audioPlayer.stop()
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
        
        let message = voiceRecognize.soundName
        print(message)
        // 再生する audio ファイルのパスを取得
        let audioPath = Bundle.main.path(forResource: message, ofType:"mp3")!
        let audioUrl = URL(fileURLWithPath: audioPath)
        print("a")
        // auido を再生するプレイヤーを作成する
        var audioError:NSError?
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
        } catch let error as NSError {
            audioError = error
            audioPlayer = nil
        }
        
        // エラーが起きたとき
        if let error = audioError {
            print("Error \(error.localizedDescription)")
        }
        
        audioPlayer.volume = Float(15.0+vol)
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.numberOfLoops = -1
        audioPlayer.play()
        print("b")
    }
    
    func startUpdatingVolume() {
        // Set data format
        var dataFormat = AudioStreamBasicDescription(
            mSampleRate: 44100.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked),
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0)
        
        // Observe input level
        var audioQueue: AudioQueueRef? = nil
        var error = noErr
        error = AudioQueueNewInput(
            &dataFormat,
            AudioQueueInputCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            .none,
            .none,
            0,
            &audioQueue)
        if error == noErr {
            self.queue = audioQueue
        }
        AudioQueueStart(self.queue, nil)
        
        // Enable level meter
        var enabledLevelMeter: UInt32 = 1
        AudioQueueSetProperty(self.queue, kAudioQueueProperty_EnableLevelMetering, &enabledLevelMeter, UInt32(MemoryLayout<UInt32>.size))
        
        isVolumeInit = true;
    }
    
    func stopUpdatingVolume() {
        AudioQueueFlush(self.queue)
        AudioQueueStop(self.queue, false)
        AudioQueueDispose(self.queue, true)
    }


}
