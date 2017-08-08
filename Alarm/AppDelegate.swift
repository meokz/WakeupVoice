import UIKit
import Foundation
import AudioToolbox
import AVFoundation

@UIApplicationMain

class AppDelegate: UIResponder, UIApplicationDelegate, AVAudioPlayerDelegate, AlarmApplicationDelegate{

    var window: UIWindow?
    var audioPlayer: AVAudioPlayer?
    let alarmScheduler: AlarmSchedulerDelegate = Scheduler()
    var alarmModel: Alarms = Alarms()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        var error: NSError?
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
            try! audioSession.setCategory(AVAudioSessionCategoryAmbient)
        } catch let error1 as NSError{
            error = error1
            print("could not set session. err:\(error!.localizedDescription)")
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error1 as NSError{
            error = error1
            print("could not active session. err:\(error!.localizedDescription)")
        }
        window?.tintColor = UIColor.red
        
        return true
    }
   
    // ローカル通知を開いたときの処理
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        
        var isSnooze: Bool = false
        var soundName: String = ""
        var index: Int = -1
        if let userInfo = notification.userInfo {
            isSnooze = userInfo["snooze"] as! Bool
            soundName = userInfo["soundName"] as! String
            index = userInfo["index"] as! Int
//            
//            //送りたいmp3ファイルの選択
//            let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate //AppDelegateのインスタンスを取得
//            appDelegate.message = soundName //appDelegateの変数を操作
        }
        
        // 通知を押すと音が消えるので，画面を開いたときに再度音を鳴らす
        playSound(soundName)
        
        // スヌーズを押したときの処理
        let snoozeOption = UIAlertAction(title: "Snooze", style: .default) {
            (action:UIAlertAction)->Void in self.audioPlayer?.stop()
            
            self.alarmScheduler.setNotificationForSnooze(snoozeMinute: 9, soundName: soundName, index: index)
        }
        
        // OKを押したときの処理
        let stopOption = UIAlertAction(title: "OK", style: .default) {
            (action:UIAlertAction)->Void in self.audioPlayer?.stop()
            
            AudioServicesRemoveSystemSoundCompletion(kSystemSoundID_Vibrate)
            self.alarmModel = Alarms()
            self.alarmModel.alarms[index].onSnooze = false
            
            // 音声認識画面の作成
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let recognizeVC = storyboard.instantiateViewController(withIdentifier: "VoiceRecognize") as? VoiceRecognizeViewController
            recognizeVC?.voiceRecognize.speechText = self.alarmModel.alarms[index].label
            recognizeVC?.voiceRecognize.soundName = soundName
            
            var mainVC = self.window?.visibleViewController as? MainAlarmViewController
            if mainVC == nil {
                // MainAlarm画面以外を開いている時
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                mainVC = storyboard.instantiateViewController(withIdentifier: "Alarm") as? MainAlarmViewController
                
                if let vc = self.window?.rootViewController?.presentedViewController {
                    vc.present(recognizeVC!, animated: true, completion: nil)
                }
            } else {
                // MainAlarm画面を開いている時
                mainVC!.present(recognizeVC!, animated: true, completion: nil)

            }
            mainVC!.changeSwitchButtonState(index: index)
        }
        
        let storageController = UIAlertController(title: "アラーム", message: nil, preferredStyle: .alert)
        if isSnooze {
            storageController.addAction(snoozeOption)
        }
        storageController.addAction(stopOption)
        
        // アプリがフォアグランドならアラート画面を表示
        window?.visibleViewController?.navigationController?.present(storageController, animated: true, completion: nil)
    }
    
    
    func showVoiceRecognize(label:String) {
        // 音声認識画面を開く

    }
    
    // snooze notification handler when app in background
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, completionHandler: @escaping () -> Void) {
        var index: Int = -1
        var soundName: String = ""
        if let userInfo = notification.userInfo {
            soundName = userInfo["soundName"] as! String
            index = userInfo["index"] as! Int
        }
        self.alarmModel = Alarms()
        self.alarmModel.alarms[index].onSnooze = false
        if identifier == Id.snoozeIdentifier {
            alarmScheduler.setNotificationForSnooze(snoozeMinute: 9, soundName: soundName, index: index)
            self.alarmModel.alarms[index].onSnooze = true
        }
        completionHandler()
    }
    
    //print out all registed NSNotification for debug
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        
        print(notificationSettings.types.rawValue)
    }
    
    //AlarmApplicationDelegate protocol
    func playSound(_ soundName: String) {
        // バイブレーションを鳴らす
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        // バイブレーションが終わった時のコールバック（延々とバイブする）
        AudioServicesAddSystemSoundCompletion(SystemSoundID(kSystemSoundID_Vibrate),nil,
            nil,
            { (_:SystemSoundID, _:UnsafeMutableRawPointer?) -> Void in
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            },
            nil)
        
        let url = URL(fileURLWithPath: Bundle.main.path(forResource: soundName, ofType: "mp3")!)
        
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
        try! audioSession.setCategory(AVAudioSessionCategoryAmbient)
        
        var error: NSError?
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch let error1 as NSError {
            error = error1
            audioPlayer = nil
        }
        
        if let err = error {
            print("audioPlayer error \(err.localizedDescription)")
            return
        } else {
            audioPlayer!.delegate = self
            audioPlayer!.prepareToPlay()
        }
        
        //negative number means loop infinity
        audioPlayer!.numberOfLoops = -1
        audioPlayer!.play()
    }
    
    //AVAudioPlayerDelegate protocol
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        
    }
   
    //UIApplicationDelegate protocol
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
//        audioPlayer?.pause()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
//        audioPlayer?.play()
        alarmScheduler.checkNotification()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    



}

