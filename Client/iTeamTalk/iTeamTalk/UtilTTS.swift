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
    applySpeechPreferences(to: myUtterance)

    synth.speak(myUtterance)
}

/// The voice, the rate and the volume chosen for the speech of the app
private func applySpeechPreferences(to utterance: AVSpeechUtterance) {
    let settings = UserDefaults.standard
    if let rate = settings.value(forKey: PREF_TTSEVENT_RATE) {
        utterance.rate = (rate as AnyObject).floatValue!
    }
    if let vol = settings.value(forKey: PREF_TTSEVENT_VOL) {
        utterance.volume = (vol as AnyObject).floatValue!
    }
    if let voice = settings.string(forKey: PREF_TTSEVENT_VOICEID) {
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice)
    }
    else if let lang = settings.string(forKey: PREF_TTSEVENT_VOICELANG) {
        utterance.voice = AVSpeechSynthesisVoice(language: lang)
    }
}

private var pendingSample: DispatchWorkItem?

/// Lets the user hear the speech of the app as it is set right now: always
/// with that voice, VoiceOver or not, because it is the one being chosen.
/// A new call replaces the one before, so dragging a slider speaks once, at
/// the end.
func speakSample(_ text: String, after delay: TimeInterval = 0) {
    pendingSample?.cancel()
    let sample = DispatchWorkItem {
        let utterance = AVSpeechUtterance(string: text)
        applySpeechPreferences(to: utterance)
        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }
    pendingSample = sample
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: sample)
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
    if msgtype == MSGTYPE_BROADCAST && settings.bool(forKey: PREF_TTSEVENT_BCASTMSG) {
        let ttsmsg = String(format: String(localized: "Broadcast message from %@. %@", comment: "TTS EVENT"),
            limitText(mymsg.nickname), mymsg.message)
        newUtterance(ttsmsg, event: PREF_TTSEVENT_BCASTMSG)
    }
}
