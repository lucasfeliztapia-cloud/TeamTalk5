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

func refVolume(_ percent: Double) -> Int {
    //82.832*EXP(0.0508*x) - 50
    if percent == 0 {
        return 0
    }
    
    let d = 82.832 * exp(0.0508 * percent) - 50
    return Int(d)
}

func refVolumeToPercent(_ volume: Int) -> Int {
    if(volume == 0) {
        return 0
    }
    
    let d = (Double(volume) + 50.0) / 82.832
    let d1 = (log(d) / 0.0508) + 0.5
    return Int(d1)
}

enum Sounds : Int {
    case tx_ON = 1,
         tx_OFF = 2,
         chan_MSG = 3,
         broadcast_MSG = 4,
         user_MSG = 5,
         srv_LOST = 6,
         joined_CHAN = 7,
         left_CHAN = 8,
         voxtriggered_ON = 9,
         voxtriggered_OFF = 10,
         transmit_ON = 11,
         transmit_OFF = 12,
         logged_IN = 13,
         logged_OUT = 14,
         file_ADDED = 15,
         file_REMOVED = 16
}

var player : AVAudioPlayer?

func getSoundFile(_ s: Sounds) -> String? {
    
    let settings = UserDefaults.standard
    
    switch s {
    case .tx_ON:
        if settings.object(forKey: PREF_SNDEVENT_VOICETX) == nil ||
           settings.bool(forKey: PREF_SNDEVENT_VOICETX) {
            return "on"
        }
    case .tx_OFF:
        if settings.object(forKey: PREF_SNDEVENT_VOICETX) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_VOICETX) {
                return "off"
        }
    case .chan_MSG:
        if settings.object(forKey: PREF_SNDEVENT_CHANMSG) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_CHANMSG) {
                return "channel_message"
        }
    case .user_MSG:
        if settings.object(forKey: PREF_SNDEVENT_USERMSG) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_USERMSG) {
                return "user_message"
        }
    case .broadcast_MSG:
        if settings.object(forKey: PREF_SNDEVENT_BCASTMSG) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_BCASTMSG) {
            return "broadcast_message"
        }
    case .srv_LOST:
        if settings.object(forKey: PREF_SNDEVENT_SERVERLOST) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_SERVERLOST) {
                return "serverlost"
        }
    case .joined_CHAN:
        if settings.object(forKey: PREF_SNDEVENT_JOINEDCHAN) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_JOINEDCHAN) {
                return "newuser"
        }
    case .left_CHAN:
        if settings.object(forKey: PREF_SNDEVENT_LEFTCHAN) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_LEFTCHAN) {
                return "removeuser"
        }
    case .voxtriggered_ON :
        if settings.object(forKey: PREF_SNDEVENT_VOXTRIGGER) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_VOXTRIGGER) {
            return "voiceact_on"
        }
    case .voxtriggered_OFF :
        if settings.object(forKey: PREF_SNDEVENT_VOXTRIGGER) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_VOXTRIGGER) {
            return "voiceact_off"
        }
    case .transmit_ON :
        if settings.object(forKey: PREF_SNDEVENT_TRANSMITREADY) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_TRANSMITREADY) {
            return "txqueue_start"
        }
    case .transmit_OFF :
        if settings.object(forKey: PREF_SNDEVENT_TRANSMITREADY) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_TRANSMITREADY) {
            return "txqueue_stop"
        }
    case .logged_IN :
        if settings.object(forKey: PREF_SNDEVENT_LOGGEDIN) != nil &&
            settings.bool(forKey: PREF_SNDEVENT_LOGGEDIN) {
            return "logged_on"
        }
    case .logged_OUT :
        if settings.object(forKey: PREF_SNDEVENT_LOGGEDOUT) != nil &&
            settings.bool(forKey: PREF_SNDEVENT_LOGGEDOUT) {
            return "logged_off"
        }
    case .file_ADDED :
        if settings.object(forKey: PREF_SNDEVENT_FILEADDED) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_FILEADDED) {
            return "file_added"
        }
    case .file_REMOVED :
        if settings.object(forKey: PREF_SNDEVENT_FILEREMOVED) == nil ||
            settings.bool(forKey: PREF_SNDEVENT_FILEREMOVED) {
            return "file_removed"
        }
    }

    return nil
}

func getCategory(_ opt: AVAudioSession.CategoryOptions) -> String {
    var str = ""
    if opt.contains(.defaultToSpeaker) {
        str += "defaultToSpeaker|"
    }
    if opt.contains(.mixWithOthers) {
        str += "mixWithOthers|"
    }
    if opt.contains(.allowBluetoothHFP) {
        str += "allowBluetoothHFP|"
    }
    if opt.contains(.duckOthers) {
        str += "duckOthers|"
    }
    if opt.contains(.interruptSpokenAudioAndMixWithOthers) {
        str += "interruptSpokenAudioAndMixWithOthers|"
    }
    if opt.contains(.overrideMutedMicrophoneInterruption) {
        str += "overrideMutedMicrophoneInterruption|"
    }
    if opt.contains(.allowAirPlay) {
        str += "allowAirPlay|"
    }
    if opt.contains(.allowBluetoothA2DP) {
        str += "allowBluetoothA2DP|"
    }
    return str
}

func getAudioPortDataSource(descr: AVAudioSessionPortDescription) -> NSNumber? {
    let defaults = UserDefaults.standard
    let prefname = PREF_SNDINPUT_PORT + "_" + descr.uid
    if let id = defaults.object(forKey: prefname) as? NSNumber {
        return id
    }
    return nil
}

func setAudioPortDataSource(descr: AVAudioSessionPortDescription, dsrc: AVAudioSessionDataSourceDescription) {
    let defaults = UserDefaults.standard
    let prefname = PREF_SNDINPUT_PORT + "_" + descr.uid
    defaults.set(dsrc.dataSourceID, forKey: prefname)
}

func removeAudioPortDataSource(descr: AVAudioSessionPortDescription) {
    let defaults = UserDefaults.standard
    let prefname = PREF_SNDINPUT_PORT + "_" + descr.uid
    defaults.removeObject(forKey: prefname)
}

func closeSoundDevices() {
    TeamTalkClient.shared.closeSoundDevices()
}

/// Keeps the microphone in use while a lost connection is being recovered.
/// Once recording has stopped iOS refuses to start it again from the
/// background, and the app would come back connected but unable to transmit.
final class MicrophoneKeepAlive {

    static let shared = MicrophoneKeepAlive()

    private var recorder: AVAudioRecorder?
    private var limit: Timer?

    var isRunning: Bool {
        recorder != nil
    }

    func start() {
        guard recorder == nil else { return }

        // nothing is kept, it records to nowhere
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        do {
            let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
            guard recorder.record() else {
                logDiagnostic("Microphone keep-alive: FAILED to start")
                return
            }
            self.recorder = recorder
            logDiagnostic("Microphone keep-alive started")
        } catch {
            logDiagnostic("Microphone keep-alive: FAILED with \(error)")
            return
        }

        // not forever: without a network it would hold the microphone for nothing
        limit = Timer.scheduledTimer(withTimeInterval: 600, repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    func stop(after delay: TimeInterval = 0) {
        guard recorder != nil else { return }

        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.stop()
            }
            return
        }

        limit?.invalidate()
        limit = nil
        recorder?.stop()
        recorder = nil
        logDiagnostic("Microphone keep-alive stopped")
    }
}

func setupSoundDevices() {
    
    do {
        closeSoundDevices()
        
        let session = AVAudioSession.sharedInstance()

        print("preset: " + session.mode.rawValue)
        
        let defaults = UserDefaults.standard
        let speaker = defaults.object(forKey: PREF_SPEAKER_OUTPUT) != nil && defaults.bool(forKey: PREF_SPEAKER_OUTPUT)
        let preprocess = defaults.object(forKey: PREF_VOICEPROCESSINGIO) != nil && defaults.bool(forKey: PREF_VOICEPROCESSINGIO)
        let a2dp = defaults.object(forKey: PREF_BLUETOOTH_A2DP) != nil && defaults.bool(forKey: PREF_BLUETOOTH_A2DP)
        let headsettoggle = defaults.object(forKey: PREF_HEADSET_TXTOGGLE) != nil && defaults.bool(forKey: PREF_HEADSET_TXTOGGLE)
                
        logDiagnostic("Sound setup: speaker=\(speaker) preprocess=\(preprocess) a2dp=\(a2dp) headsettoggle=\(headsettoggle)")

        // In 'voiceChat' mode stereo cannot be enabled on input devices.
        try session.setMode(preprocess ? .voiceChat : .default)

        var catoptions : AVAudioSession.CategoryOptions
        
        // Toggling 'speaker' on iPad has no effect since it can only output to speaker.
        // When Bluetooth headset is connected to iPad then toggling 'speaker' will have
        // no effect. However, on iPhone toggling 'speaker' has the desired effect both
        // when switching output from Receiver and Bluetooth to 'speaker'.
        if speaker {
            catoptions = [ .defaultToSpeaker ]
        } else {
            catoptions = [ .allowBluetoothHFP, .allowAirPlay, .allowBluetoothA2DP ]
            if #available(iOS 26.0, *) {
                catoptions.update(with: .bluetoothHighQualityRecording)
            }
            if a2dp {
                catoptions.remove(.allowBluetoothHFP)
            }
        }
        // headset notifications, UIApplication.shared.beginReceivingRemoteControlEvents(),
        // will be ignored with .mixWithOthers
        if headsettoggle == false {
            catoptions.update(with: .mixWithOthers)
        }
        
        try session.setCategory(.playAndRecord, options: catoptions)

        // Note that Voice Preprocessing IO will disable ability to select
        // stereo microphone sources
        let sndid = preprocess ? TeamTalkSoundDeviceID.voiceProcessingIO : TeamTalkSoundDeviceID.remoteIO
        if !TeamTalkClient.shared.initSoundInputDevice(id: sndid) {
            print("Failed to initialize sound input device: \(sndid)")
            logDiagnostic("Sound setup: FAILED to open input device \(sndid)")
        }
        else {
            print("Using sound input device: \(sndid)")
        }
        if !TeamTalkClient.shared.initSoundOutputDevice(id: sndid) {
            print("Failed to initialize sound output device: \(sndid)")
            logDiagnostic("Sound setup: FAILED to open output device \(sndid)")
        }
        else {
            print("Using sound output device: \(sndid)")
        }
        print("postset. Mode \(session.mode.rawValue), category \(session.category.rawValue), options \(getCategory(session.categoryOptions))")
        logDiagnostic("Sound setup done: device \(sndid), mode \(session.mode.rawValue), options \(getCategory(session.categoryOptions)), route \(describeAudioRoute(session))")
        
        // enable stereo on all data sources that support it
        for input in session.availableInputs ?? [] {
            guard let dataSourceID = getAudioPortDataSource(descr: input) else { continue }
            for datasrc in input.dataSources ?? [] {
                if datasrc.dataSourceID == dataSourceID {
                    if datasrc.supportedPolarPatterns?.contains(.stereo) == true {
                        try datasrc.setPreferredPolarPattern(.stereo)
                        print("Setting \(datasrc.dataSourceName) to stereo")
                    } else {
                        print("No stereo on \(datasrc.dataSourceName)")
                    }
                }
                if session.inputDataSource?.dataSourceID != dataSourceID {
                    try input.setPreferredDataSource(datasrc)
                }
            }
        }
    }
    catch {
        print("Failed to set mode")
        logDiagnostic("Sound setup: FAILED with \(error)")
    }
}

/// "inputs -> outputs" of the route in use, for the diagnostic log
func describeAudioRoute(_ session: AVAudioSession) -> String {
    let inputs = session.currentRoute.inputs.map { $0.portName }.joined(separator: "+")
    let outputs = session.currentRoute.outputs.map { $0.portName }.joined(separator: "+")
    return "\(inputs.isEmpty ? "none" : inputs) -> \(outputs.isEmpty ? "none" : outputs)"
}

func playSound(_ s: Sounds) {
    
    let filename = getSoundFile(s)
    
    if filename == nil {
        return
    }
    
    if let resPath = Bundle.main.path(forResource: filename, ofType: "mp3")
        ?? Bundle.main.path(forResource: filename, ofType: "wav") {
        
        let url = URL(fileURLWithPath: resPath)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player!.prepareToPlay()
            player!.play()
        }
        catch {
            print("Failed to play")
        }
    }
}
