//
//  SpeechModel.swift
//  Alarm-ios-swift
//
//  Created by Kazuki Otao on 2017/08/02.
//  Copyright © 2017年 LongGames. All rights reserved.
//

import Foundation

struct VoiceRecognizeModel {
    var speechText : String = "おはよう"
    var isRecognized : Bool = false
    var isVolume : Bool = false
    var volume : Float = 10.00
    var soundName : String = "bell"
}
