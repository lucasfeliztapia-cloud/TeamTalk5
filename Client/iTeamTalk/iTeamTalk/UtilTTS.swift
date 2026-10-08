/*
 * Copyright (c) 2005-2018, BearWare.dk
 *
 * Contact Information:
 *
 * Bjoern D. Rasmussen
 * Kirketoften 5
 * DK-8260 Viby J
 * Denmark
 * Email: contact@bearware.dk
 * Phone: +45 20 20 54 59
 * Web: http://www.bearware.dk
 *
 * This source code is part of the TeamTalk SDK owned by
 * BearWare.dk. Use of this file, or its compiled unit, requires a
 * TeamTalk SDK License Key issued by BearWare.dk.
 *
 * The TeamTalk SDK License Agreement along with its Terms and
 * Conditions are outlined in the file License.txt included with the
 * TeamTalk SDK distribution.
 *
 */

import Foundation
import AVFoundation
import TeamTalkKit
import UIKit

// initialize TTS values globally
let synth = AVSpeechSynthesizer()
var myUtterance = AVSpeechUtterance(string: "")

// what an utterance has until the slider is moved, so the slider shows it
let DEFAULT_TTS_VOL : Float = 1.0

/// Added to the preference of an event: true makes the app's own voice speak
/// it even while VoiceOver is on.
let PREF_TTSEVENT_OWNVOICE_SUFFIX = "_ownvoice"

/// `event` is the preference of the event being spoken. VoiceOver speaks it,
/// and shows it in braille, unless that event is set to the app's own voice.
func newUtterance(_ utterance: String, event: String? = nil) {
    let settings = UserDefaults.standard
    myUtterance = AVSpeechUtterance(string: utterance)
    let ownVoice = event.map { settings.bool(forKey: $0 + PREF_TTSEVENT_OWNVOICE_SUFFIX) } ?? false
    if !ownVoice && UIAccessibility.isVoiceOverRunning && UIApplication.shared.applicationState == .active{
        UIAccessibility.post(notification: UIAccessibility.Notification.announcement, argument: utterance)
        return
    }
    if let rate = settings.value(forKey: PREF_TTSEVENT_RATE) {
        myUtterance.rate = (rate as AnyObject).floatValue!
    }
    if let vol = settings.value(forKey: PREF_TTSEVENT_VOL) {
        myUtterance.volume = (vol as AnyObject).floatValue!
    }
    if let voice = settings.string(forKey: PREF_TTSEVENT_VOICEID) {
        myUtterance.voice = AVSpeechSynthesisVoice(identifier: voice)
    }
    else if let lang = settings.string(forKey: PREF_TTSEVENT_VOICELANG) {
        myUtterance.voice = AVSpeechSynthesisVoice(language: lang)
    }
    
    synth.speak(myUtterance)
}

func speakTextMessage(_ msgtype: TextMsgType, mymsg: MyTextMessage) {
    
    let settings = UserDefaults.standard
    let tts_priv = settings.object(forKey: PREF_TTSEVENT_TEXTMSG) != nil && settings.bool(forKey: PREF_TTSEVENT_TEXTMSG) && msgtype == MSGTYPE_USER
    let tts_chan = settings.object(forKey: PREF_TTSEVENT_CHANTEXTMSG) != nil && settings.bool(forKey: PREF_TTSEVENT_CHANTEXTMSG) && msgtype == MSGTYPE_CHANNEL
    
    if tts_priv {
        let ttsmsg = String(format: String(localized: "Private text message from %@. %@", comment: "TTS EVENT"),
            limitText(mymsg.nickname), mymsg.message)
        newUtterance(ttsmsg, event: PREF_TTSEVENT_TEXTMSG)
    }
    if tts_chan {
        let ttsmsg = String(format: String(localized: "Channel message from %@. %@", comment: "TTS EVENT"),
            limitText(mymsg.nickname), mymsg.message)
        newUtterance(ttsmsg, event: PREF_TTSEVENT_CHANTEXTMSG)
    }
}
