//
//  MusicViewController.swift
//  Alarm-ios-swift
//
//  Created by 小川大河 on 2017/08/02.
//  Copyright © 2017年 LongGames. All rights reserved.
//

import UIKit
import AVFoundation

class MusicViewController: UIViewController, AVAudioPlayerDelegate {
    
    var audioPlayer:AVAudioPlayer!
    
    @IBOutlet var button:UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 再生する audio ファイルのパスを取得
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate //AppDelegateのインスタンスを取得
//        var message = appDelegate.message
//        let audioPath = Bundle.main.path(forResource: message, ofType:"mp3")!
        //let audioPath = Bundle.main.path(forResource: "bell", ofType:"mp3")!
//        let audioUrl = URL(fileURLWithPath: audioPath)
        
        
        // auido を再生するプレイヤーを作成する
        var audioError:NSError?
        do {
//            audioPlayer = try AVAudioPlayer(contentsOf: audioUrl)
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
        
    }
    
    // ボタンがタップされた時の処理
    @IBAction func buttonTapped(_ sender : AnyObject) {
        if ( audioPlayer.isPlaying ){
            audioPlayer.stop()
            button.setTitle("Stop", for: UIControlState())
        }
        else{
            audioPlayer.play()
            button.setTitle("Play", for: UIControlState())
        }
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


 
