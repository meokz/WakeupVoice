import Foundation

import UIKit
import Speech
import AVFoundation
import Pulsator

public class VoiceRecognizeViewController : UIViewController,
    SFSpeechRecognizerDelegate ,AVAudioPlayerDelegate {
    
    @IBOutlet weak var  textView: UILabel!
    @IBOutlet var recordButton : UIButton!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sourceView: UIImageView!
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    let audioEngine = AVAudioEngine()
    
    let checkButtonImage :UIImage? = UIImage(named:"check.png")

    var audioPlayer:AVAudioPlayer!
    
    var vol = 1.0
    
    private var voiceRecognize : VoiceRecognizeModel = VoiceRecognizeModel()

    let pulsator = Pulsator()

    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false

        // 時間の設定
        timeDisplay()
        _ = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(timeDisplay), userInfo: nil, repeats: true)

        let text = "\"" + self.voiceRecognize.speechText + "\"";
        self.textView.text = text + "\nと言ってください"
        self.textView.numberOfLines = 2
        playSound()
        
        sourceView.layer.superlayer?.insertSublayer(pulsator, below: sourceView.layer)
        pulsator.start()
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
                if voice == self.voiceRecognize.speechText {
                    self.voiceRecognize.isRecognized = true;
                }
                
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
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
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
//            recordButton.setTitle("認識開始", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("認識できません", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    @IBAction func recordButtonTapped() {
        if !voiceRecognize.isRecognized {
            // 音声認識開始
            if ( audioPlayer.isPlaying ){
                audioPlayer.stop()
            }
            try! startRecording()
            recordButton.setTitle("認識中止", for: [])
        } else {
            // アラームリストを開く
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let recognizeVC = storyboard.instantiateViewController(withIdentifier: "Navigation") as? UINavigationController
            self.present(recognizeVC!, animated: true, completion: nil)
            
        }
    }
    
    @IBAction func recordButtonReleased() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("中止しています", for: .disabled)
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
        timeLabel.adjustsFontSizeToFitWidth = true
        textView.adjustsFontSizeToFitWidth = true

    }
    
    func endRecognization() {
        if voiceRecognize.isRecognized {
            // 正解，音を止める
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            
            let text = "\"" + voiceRecognize.speechText + "\"";
            textView.text = text  + "と言いました"
          
            // チェックボタンの変更
            self.recordButton.setImage(self.checkButtonImage!, for: .normal)
        } else {
            // 不正解，音を再生
            vol += 10.0
            let audioSession = AVAudioSession.sharedInstance()
            try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
            playSound()
            
            let text = "\"" + voiceRecognize.speechText + "\"";
            textView.text = text  + "と言ってください"
        }
        recordButton.isEnabled = true
        
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
        
        audioPlayer.volume = Float(15.0+vol)
        audioPlayer.delegate = self
        audioPlayer.prepareToPlay()
        audioPlayer.play()
    }
}
