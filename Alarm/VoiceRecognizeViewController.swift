import Foundation

import UIKit
import Speech
import AVFoundation

public class VoiceRecognizeViewController : UIViewController, SFSpeechRecognizerDelegate ,AVAudioPlayerDelegate{
    // MARK: Properties
    
    var audioPlayer:AVAudioPlayer!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView : UITextView!
    
    @IBOutlet var recordButton : UIButton!
    
    @IBOutlet weak var timeLabel: UILabel!
    private var voiceRecognize : VoiceRecognizeModel = VoiceRecognizeModel()
    
    // MARK: UIViewController
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false

        // 時間の設定
        timeDisplay()
        _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timeDisplay), userInfo: nil, repeats: true)
        
        playSound()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("ユーザが音声認識を許可しませんでした", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("このデバイスでの音声認識は制限されています", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("音声認識はまだ許可されていません", for: .disabled)
                }
            }
        }
    }
    
    private func startRecording() throws {
        // Cancel the previous task if it's running.
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
                
                if voice == self.voiceRecognize.speechText {
                    self.audioEngine.stop()
                    self.recognitionRequest?.endAudio()
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("中止しています", for: .disabled)
                    self.voiceRecognize.isRecognized = true
                }
                
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
     
                self.recordButton.isEnabled = true
                if self.voiceRecognize.isRecognized {
                    let text = "\"" + self.voiceRecognize.speechText + "\"";
                    self.recordButton.setTitle(text + "といいました", for: [])
                    
                    //バグ
                    self.audioPlayer.stop()
                } else {
                    self.recordButton.setTitle("認識開始", for: [])
                }
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
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("認識開始", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("認識できません", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("中止しています", for: .disabled)
        } else {
            try! startRecording()
            recordButton.setTitle("認識中止", for: [])
        }
    }
    
    public func timeDisplay(){
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.ReferenceType.local
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let date  = Date()
        let datestr = formatter.string(from :date)
        let  dateComponents = datestr.components(separatedBy: "-")
        let hour = dateComponents[3]
        let minute = dateComponents[4]
        timeLabel.text = hour + ":" + minute
    }
    
    
    func playSound() {
        // 再生する audio ファイルのパスを取得
        let audioPath = Bundle.main.path(forResource: "bell", ofType:"mp3")!
        let audioUrl = URL(fileURLWithPath: audioPath)
        
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
        
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.play()
    }

}
