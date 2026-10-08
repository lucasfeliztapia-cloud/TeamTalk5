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

import AVFoundation
import Combine
import OSLog
import SwiftUI
import TeamTalkKit
import UIKit
import WidgetKit

final class MainTabModel: ObservableObject, TeamTalkEvent {

    let channelListModel: ChannelListModel
    let channelChatModel: TextMessageModel
    let fileListModel: FileListModel
    let mediaStreamModel: MediaStreamModel
    let preferencesModel: PreferencesModel

    var server: Server
    var cmdid: INT32 = 0

    @Published var alertMessage: String?

    /// A file from another app, offered once there is a channel to send it to
    @Published var incomingFile: SharedFile?
    private var offeredFileID: UUID?
    private var hintedFileID: UUID?

    private var soundDevicesFailed = false
    private var lastSoundRecovery = Date.distantPast
    @Published var fatalAlertMessage: String?   // dismisses the view when OK tapped
    @Published var showSaveAlert = false

    private var pendingDismiss: (() -> Void)?
    private var polltimer: Timer?
    private var reconnecttimer: Timer?
    private var didSetup = false
    private var liveActivityUpdatePending = false
    private var cancellables = Set<AnyCancellable>()

    init(server: Server) {
        self.server = server
        channelListModel = ChannelListModel()
        channelChatModel = TextMessageModel(
            userid: 0,
            title: String(localized: "Messages", comment: "tab")
        )
        fileListModel = FileListModel()
        mediaStreamModel = MediaStreamModel()
        preferencesModel = PreferencesModel()
        channelListModel.openTextMessages(channelChatModel)
    }

    deinit {
        TeamTalkClient.shared.disconnect()
        closeSoundDevices()
        runTeamTalkEventHandler()
        print("Destroyed main view controller")
    }

    func setup() {
        guard !didSetup else { return }
        didSetup = true

        addToTTMessages(self)
        addToTTMessages(channelListModel)
        addToTTMessages(channelChatModel)
        addToTTMessages(fileListModel)
        addToTTMessages(mediaStreamModel)

        LiveActivityActions.toggleTransmission = { [weak self] in
            self?.channelListModel.txBtnAccessibilityAction()
        }
        LiveActivityActions.toggleDeafen = { [weak self] in
            self?.channelListModel.toggleDeafen()
        }
        LiveActivityActions.toggleStreamPause = { [weak self] in
            self?.mediaStreamModel.togglePause()
        }
        LiveActivityActions.stopStream = { [weak self] in
            self?.mediaStreamModel.stop()
        }
        LiveActivityActions.setTransmission = { [weak self] enable in
            guard let self, TeamTalkClient.shared.isVoiceTransmitting != enable else { return }
            self.channelListModel.enableVoiceTx(enable)
            // the control reads the new state as soon as this returns
            self.updateLiveActivity()
        }
        LiveActivityActions.setSpeakers = { [weak self] on in
            guard let self, TeamTalkClient.shared.isSoundOutputMuted == on else { return }
            self.channelListModel.toggleDeafen()
            self.updateLiveActivity()
        }
        IncomingFileModel.shared.$pending
            .sink { [weak self] _ in
                self?.scheduleLiveActivityUpdate()
            }
            .store(in: &cancellables)
        // without the position, which changes every second while streaming
        mediaStreamModel.$state.map { _ in () }
            .merge(with: mediaStreamModel.$currentID.map { _ in () })
            .sink { [weak self] _ in
                self?.scheduleLiveActivityUpdate()
            }
            .store(in: &cancellables)
        channelListModel.$isTransmitting
            .merge(with: channelListModel.$isDeafened)
            .sink { [weak self] _ in
                self?.scheduleLiveActivityUpdate()
            }
            .store(in: &cancellables)
        AppearanceModel.shared.objectWillChange
            .sink { [weak self] _ in
                self?.scheduleLiveActivityUpdate()
            }
            .store(in: &cancellables)
        addToTTMessages(preferencesModel)

        setupSoundDevices()
        channelListModel.isDeafened = TeamTalkClient.shared.isSoundOutputMuted

        let defaults = UserDefaults.standard
        if defaults.object(forKey: PREF_MASTER_VOLUME) != nil {
            let vol = defaults.integer(forKey: PREF_MASTER_VOLUME)
            TeamTalkClient.shared.setSoundOutputVolume(INT32(refVolume(Double(vol))))
        }
        if defaults.object(forKey: PREF_VOICEACTIVATION) != nil {
            let voiceact = defaults.integer(forKey: PREF_VOICEACTIVATION)
            if voiceact != VOICEACT_DISABLED {
                TeamTalkClient.shared.enableVoiceActivation(true)
                TeamTalkClient.shared.setVoiceActivationLevel(INT32(voiceact))
            }
        }
        if defaults.object(forKey: PREF_MICROPHONE_GAIN) != nil {
            let vol = defaults.integer(forKey: PREF_MICROPHONE_GAIN)
            TeamTalkClient.shared.setSoundInputGainLevel(INT32(refVolume(Double(vol))))
        }

        polltimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(timerEvent),
            userInfo: nil,
            repeats: true
        )

        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(proximityChanged(_:)),
            name: UIDevice.proximityStateDidChangeNotification,
            object: UIDevice.current
        )
        center.addObserver(
            self, selector: #selector(audioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        center.addObserver(
            self, selector: #selector(audioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self, selector: #selector(audioConfigChanged(_:)),
            name: .iTeamTalkAudioConfigChanged,
            object: nil
        )
        center.addObserver(
            self, selector: #selector(appDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        connectToServer()
    }

    func teardown() {
        logDiagnostic("Session closed")
        cancellables.removeAll()
        LiveActivityActions.toggleTransmission = nil
        LiveActivityActions.toggleDeafen = nil
        LiveActivityActions.toggleStreamPause = nil
        LiveActivityActions.stopStream = nil
        LiveActivityActions.setTransmission = nil
        LiveActivityActions.setSpeakers = nil
        LiveActivityController.end()
        publishSharedState(connected: false, transmitting: false, deafened: false)
        MicrophoneKeepAlive.shared.stop()
        polltimer?.invalidate()
        reconnecttimer?.invalidate()
        removeAllTTMessageHandlers()
        unreadmessages.removeAll()
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    func onVisibleAppear() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PREF_DISPLAY_PROXIMITY) != nil &&
            defaults.bool(forKey: PREF_DISPLAY_PROXIMITY) {
            UIDevice.current.isProximityMonitoringEnabled = true
        }
        if defaults.object(forKey: PREF_HEADSET_TXTOGGLE) != nil &&
            defaults.bool(forKey: PREF_HEADSET_TXTOGGLE) {
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
    }

    func remoteControl(_ event: UIEvent?) {
        guard let rc = event?.subtype else { return }
        switch rc {
        case .remoteControlPause, .remoteControlTogglePlayPause:
            channelListModel.enableVoiceTx(false)
        case .remoteControlPreviousTrack, .remoteControlNextTrack:
            channelListModel.enableVoiceTx(true)
        default:
            break
        }
    }

    func disconnectTapped(dismiss: @escaping () -> Void) {
        let servers = loadLocalServers()
        let found = servers.filter {
            $0.ipaddr == server.ipaddr &&
            $0.tcpport == server.tcpport &&
            $0.udpport == server.udpport &&
            $0.username == server.username
        }
        if found.isEmpty && server.servertype == .LOCAL {
            pendingDismiss = { dismiss() }
            showSaveAlert = true
        } else {
            dismiss()
        }
    }

    func saveAndDisconnect(name: String) {
        var servers = loadLocalServers()
        servers = servers.filter { $0.name != name }
        server.name = name
        servers.append(server)
        saveLocalServers(servers)
        pendingDismiss?()
        pendingDismiss = nil
    }

    func skipSaveAndDisconnect() {
        pendingDismiss?()
        pendingDismiss = nil
    }

    func startReconnectTimer() {
        reconnecttimer = Timer.scheduledTimer(
            timeInterval: 5.0,
            target: self,
            selector: #selector(connectToServer),
            userInfo: nil,
            repeats: false
        )
    }

    @objc func connectToServer() {
        logDiagnostic("Connecting to \(server.ipaddr) tcp=\(server.tcpport) udp=\(server.udpport) encrypted=\(server.encrypted)")
        if !setupEncryption(server: server) {
            fatalAlertMessage = String(localized: "Failed to setup encryption", comment: "connect to a server")
        } else if !TeamTalkClient.shared.connect(
            toHost: server.ipaddr,
            tcpPort: INT32(server.tcpport),
            udpPort: INT32(server.udpport),
            encrypted: server.encrypted
        ) {
            TeamTalkClient.shared.disconnect()
            startReconnectTimer()
        }
    }

    @objc private func timerEvent() {
        runTeamTalkEventHandler()
    }

    @objc private func proximityChanged(_ notification: Notification) {}

    @objc private func audioConfigChanged(_ notification: Notification) {
        if channelListModel.mychannel.nChannelID > 0 {
            channelListModel.updateAudioConfig()
        }
    }

    // MARK: - Keyboard

    func performKeyboardAction(_ action: KeyboardAction) {
        switch action {
        case .transmit:
            channelListModel.txBtnAccessibilityAction()
        case .speakers:
            channelListModel.toggleDeafen()
        case .streamPause:
            mediaStreamModel.togglePause()
        case .streamStop:
            mediaStreamModel.stop()
        }
    }

    @objc private func audioRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        logDiagnostic("Audio route change, reason \(reasonValue): \(describeAudioRoute(AVAudioSession.sharedInstance()))")
        switch reason {
        case .oldDeviceUnavailable:
            setupSoundDevices()
        default:
            break
        }
        print(AVAudioSession.sharedInstance().currentRoute)
    }

    @objc private func audioInterruption(_ notification: Notification) {
        guard let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
        logDiagnostic("Audio interruption ended, shouldResume=\(options.contains(.shouldResume))")
        if options.contains(.shouldResume) {
            setupSoundDevices()
        }
    }

    // MARK: - Diagnostics

    private func logEvent(_ m: TTMessage) {
        switch m.nClientEvent {
        case CLIENTEVENT_USER_STATECHANGE, CLIENTEVENT_FILETRANSFER, CLIENTEVENT_STREAM_MEDIAFILE,
             CLIENTEVENT_LOCAL_MEDIAFILE, CLIENTEVENT_USER_FIRSTVOICESTREAMPACKET,
             CLIENTEVENT_CMD_USER_UPDATE, CLIENTEVENT_CMD_CHANNEL_NEW, CLIENTEVENT_CMD_USER_LOGGEDIN,
             CLIENTEVENT_CMD_FILE_NEW:
            // too many of them, and their own models log what matters
            break
        case CLIENTEVENT_CMD_ERROR:
            let error = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            logDiagnostic("CMD_ERROR cmd=\(m.nSource): \(error)")
        case CLIENTEVENT_INTERNAL_ERROR:
            let error = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            logDiagnostic("INTERNAL_ERROR: \(error)")
        case CLIENTEVENT_CMD_USER_JOINED, CLIENTEVENT_CMD_USER_LEFT:
            let user = TeamTalkMessagePayload.user(from: m)
            let me = user.nUserID == TeamTalkClient.shared.myUserID ? " (me)" : ""
            logDiagnostic("\(clientEventName(m.nClientEvent)) user=\(user.nUserID)\(me) channel=\(user.nChannelID) flags=\(String(TeamTalkClient.shared.flags.rawValue, radix: 16))")
        default:
            logDiagnostic("\(clientEventName(m.nClientEvent)) source=\(m.nSource) flags=\(String(TeamTalkClient.shared.flags.rawValue, radix: 16))")
        }
    }

    // MARK: - Controls in Control Center

    /// What the controls show. They read it from the group the app shares
    /// with its widgets, when the app was signed with one.
    private func publishSharedState(connected: Bool, transmitting: Bool, deafened: Bool) {
        guard let shared = SharedStore.defaults else { return }
        guard shared.bool(forKey: SharedStore.connectedKey) != connected ||
              shared.bool(forKey: SharedStore.transmittingKey) != transmitting ||
              shared.bool(forKey: SharedStore.deafenedKey) != deafened else { return }

        shared.set(connected, forKey: SharedStore.connectedKey)
        shared.set(transmitting, forKey: SharedStore.transmittingKey)
        shared.set(deafened, forKey: SharedStore.deafenedKey)

        if #available(iOS 18.0, *) {
            ControlCenter.shared.reloadControls(ofKind: SharedStore.transmitControlKind)
            ControlCenter.shared.reloadControls(ofKind: SharedStore.speakersControlKind)
        }
    }

    // MARK: - Sound devices after a reconnect

    /// When the connection is lost and found again with the app in the
    /// background, iOS can refuse to start the microphone. The app was left
    /// connected but unable to transmit until disconnecting by hand (#1974).
    private func watchSoundDevices(_ m: TTMessage) {
        switch m.nClientEvent {
        case CLIENTEVENT_CON_LOST:
            if channelListModel.mychannel.nChannelID > 0 {
                // holds the microphone until the channel takes it back
                MicrophoneKeepAlive.shared.start()
            }
        case CLIENTEVENT_CMD_USER_JOINED:
            if MicrophoneKeepAlive.shared.isRunning,
               TeamTalkMessagePayload.user(from: m).nUserID == TeamTalkClient.shared.myUserID {
                MicrophoneKeepAlive.shared.stop(after: 3)
            }
        case CLIENTEVENT_INTERNAL_ERROR:
            let error = TeamTalkMessagePayload.clientError(from: m).nErrorNo
            if error == INT32(INTERR_SNDINPUT_FAILURE.rawValue) || error == INT32(INTERR_SNDOUTPUT_FAILURE.rawValue) {
                soundDevicesFailed = true
                recoverSoundDevices()
            }
        default:
            break
        }
    }

    /// Opens the sound devices again. iOS only allows it with the app in
    /// front, so in the background it waits until the app comes back.
    private func recoverSoundDevices() {
        guard soundDevicesFailed, UIApplication.shared.applicationState == .active,
              Date().timeIntervalSince(lastSoundRecovery) > 10 else { return }
        soundDevicesFailed = false
        lastSoundRecovery = Date()
        logDiagnostic("Sound devices failed, setting them up again")
        setupSoundDevices()
    }

    @objc private func appDidBecomeActive(_ notification: Notification) {
        recoverSoundDevices()
    }

    // MARK: - Files from other apps

    /// Offers the file another app handed over, once there is a channel for it
    private func offerIncomingFile() {
        guard didSetup, let pending = IncomingFileModel.shared.pending else { return }

        if channelListModel.mychannel.nChannelID > 0 {
            guard pending.id != offeredFileID else { return }
            offeredFileID = pending.id
            incomingFile = pending
        } else if TeamTalkClient.shared.isAuthorized, pending.id != hintedFileID {
            // said once, the file is offered when a channel is joined
            hintedFileID = pending.id
            announceForAccessibility(String(format: String(localized: "Join a channel to send %@", comment: "incoming file"),
                                            pending.url.lastPathComponent))
        }
    }

    func uploadIncomingFile(_ file: SharedFile) {
        IncomingFileModel.shared.clear()
        fileListModel.uploadOwnedFile(file.url)
    }

    func streamIncomingFile(_ file: SharedFile) {
        IncomingFileModel.shared.clear()
        mediaStreamModel.addFiles([file.url])
        announceForAccessibility(String(localized: "Added to the streaming playlist", comment: "incoming file"))
    }

    // MARK: - Live Activity

    /// The other models handle each event after this one and @Published tells
    /// before it changes, so the state is read once they have all settled.
    private func scheduleLiveActivityUpdate() {
        guard !liveActivityUpdatePending else { return }
        liveActivityUpdatePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.liveActivityUpdatePending = false
            self.updateLiveActivity()
            self.offerIncomingFile()
        }
    }

    private func updateLiveActivity() {
        guard didSetup, polltimer?.isValid == true else { return }

        let channels = channelListModel
        var serverName = TeamTalkString.serverProperties(.name, from: channels.srvprop)
        if serverName.isEmpty {
            serverName = server.name.isEmpty ? server.ipaddr : server.name
        }

        let connected = TeamTalkClient.shared.isAuthorized
        let statusText: String
        if !connected {
            statusText = String(localized: "Connection lost", comment: "tts event")
        } else if channels.mychannel.nChannelID > 0 {
            let name = channels.mychannel.nParentID == 0
                ? serverName
                : TeamTalkString.channel(.name, from: channels.mychannel)
            let count = channels.users.values.filter { $0.nChannelID == channels.mychannel.nChannelID }.count
            statusText = String(format: String(localized: "%@, %d users", comment: "live activity"), name, count)
        } else {
            statusText = String(localized: "Not in a channel", comment: "live activity")
        }

        let appearance = AppearanceModel.shared
        let transmitting = TeamTalkClient.shared.isVoiceTransmitting
        let deafened = TeamTalkClient.shared.isSoundOutputMuted

        publishSharedState(connected: connected, transmitting: transmitting, deafened: deafened)
        LiveActivityController.update(LiveActivityStatus(
            serverName: serverName,
            statusText: statusText,
            isConnected: connected,
            isTransmitting: transmitting,
            isDeafened: deafened,
            talkColor: AppearanceModel.hex(of: transmitting ? appearance.talkActiveColor : appearance.talkIdleColor),
            speakersColor: AppearanceModel.hex(of: deafened ? appearance.speakersMutedColor : appearance.speakersOnColor),
            streamName: mediaStreamModel.isStreaming ? mediaStreamModel.fileName : "",
            isStreamPaused: mediaStreamModel.state == .paused
        ))
    }

    func handleTTMessage(_ m: TTMessage) {
        scheduleLiveActivityUpdate()
        logEvent(m)
        watchSoundDevices(m)

        switch m.nClientEvent {

        case CLIENTEVENT_CON_SUCCESS:
            os_log("Connected to \(self.server.ipaddr)")

            if AppInfo.isBearWareWebLogin(self.server.username) {
                let settings = UserDefaults.standard
                let username = settings.string(forKey: PREF_GENERAL_BEARWARE_ID) ?? ""
                let token = settings.string(forKey: PREF_GENERAL_BEARWARE_TOKEN) ?? ""
                let accesstoken = TeamTalkClient.shared.withServerProperties {
                    TeamTalkString.serverProperties(.accessToken, from: $0)
                }
                let url = AppInfo.getBearWareServerTokenURL(
                    username: username, token: token, accesstoken: accesstoken
                )
                let authParser = WebLoginParser()
                if let tokenURL = URL(string: url), let parser = XMLParser(contentsOf: tokenURL) {
                    parser.delegate = authParser
                    if parser.parse() && authParser.username.count > 0 {
                        self.server.username = authParser.username
                        self.server.password = AppInfo.WEBLOGIN_BEARWARE_PASSWDPREFIX + authParser.token
                    }
                }
                if self.server.username == AppInfo.WEBLOGIN_BEARWARE_USERNAME {
                    alertMessage = String(localized: "BearWare.dk Web Login failed to authenticate. Check BearWare.dk Web Login in Preferences", comment: "weblogin event")
                }
            }
            login()

        case CLIENTEVENT_CON_FAILED:
            TeamTalkClient.shared.disconnect()
            startReconnectTimer()
            os_log("Connect to \(self.server.ipaddr) failed")

        case CLIENTEVENT_CON_LOST:
            os_log("Connection to \(self.server.ipaddr) lost")
            TeamTalkClient.shared.disconnect()
            playSound(.srv_LOST)
            if UserDefaults.standard.object(forKey: PREF_TTSEVENT_CONLOST) == nil ||
                UserDefaults.standard.bool(forKey: PREF_TTSEVENT_CONLOST) {
                newUtterance(String(localized: "Connection lost", comment: "tts event"), event: PREF_TTSEVENT_CONLOST)
            }
            startReconnectTimer()

        case CLIENTEVENT_VOICE_ACTIVATION:
            playSound(TeamTalkMessagePayload.isActive(m) ? .voxtriggered_ON : .voxtriggered_OFF)

        case CLIENTEVENT_CMD_PROCESSING:
            if !TeamTalkMessagePayload.isActive(m) {
                commandComplete(m.nSource)
            }

        case CLIENTEVENT_CMD_MYSELF_LOGGEDIN:
            let account = TeamTalkMessagePayload.userAccount(from: m)
            let initchan = TeamTalkString.userAccount(.initialChannel, from: account)
            if !initchan.isEmpty {
                server.channel = initchan
            }
            saveLastServer(server)

        case CLIENTEVENT_CMD_MYSELF_KICKED:
            let msg: String
            if TeamTalkMessagePayload.hasUserPayload(m) {
                let kicker = getDisplayName(TeamTalkMessagePayload.user(from: m))
                msg = m.nSource == 0
                    ? String(format: String(localized: "You have been kicked from server by %@", comment: "Dialog"), kicker)
                    : String(format: String(localized: "You have been kicked from channel by %@", comment: "Dialog"), kicker)
            } else {
                msg = m.nSource == 0
                    ? String(localized: "You have been kicked from server", comment: "Dialog")
                    : String(localized: "You have been kicked from channel", comment: "Dialog")
            }
            if m.nSource == 0 { playSound(.srv_LOST) }
            alertMessage = msg

        case CLIENTEVENT_CMD_ERROR:
            if m.nSource == cmdid {
                fatalAlertMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
                reconnecttimer?.invalidate()
                TeamTalkClient.shared.disconnect()
            }

        case CLIENTEVENT_CMD_USER_LOGGEDIN:
            let subs = getDefaultSubscriptions()
            let user = TeamTalkMessagePayload.user(from: m)
            if TeamTalkClient.shared.myUserID != user.nUserID && user.uLocalSubscriptions != subs {
                TeamTalkClient.shared.unsubscribe(userID: user.nUserID, subscriptions: user.uLocalSubscriptions ^ subs)
            }
            syncFromUserCache(user: user)

        case CLIENTEVENT_CMD_USER_LOGGEDOUT:
            syncToUserCache(user: TeamTalkMessagePayload.user(from: m))

        case CLIENTEVENT_CMD_USER_JOINED:
            let user = TeamTalkMessagePayload.user(from: m)
            let defaults = UserDefaults.standard
            if let mfvol = defaults.object(forKey: PREF_MEDIAFILE_VOLUME) as? Double {
                let vol = refVolume(100.0 * mfvol)
                TeamTalkClient.shared.setUserVolume(
                    userID: user.nUserID, stream: STREAMTYPE_MEDIAFILE_AUDIO, volume: INT32(vol)
                )
                TeamTalkClient.shared.pump(CLIENTEVENT_USER_STATECHANGE, source: user.nUserID)
            }
            if (TeamTalkClient.shared.myUserRights & USERRIGHT_VIEW_ALL_USERS.rawValue) != USERRIGHT_VIEW_ALL_USERS.rawValue {
                syncFromUserCache(user: user)
            }

        case CLIENTEVENT_CMD_USER_LEFT:
            if (TeamTalkClient.shared.myUserRights & USERRIGHT_VIEW_ALL_USERS.rawValue) != USERRIGHT_VIEW_ALL_USERS.rawValue {
                syncToUserCache(user: TeamTalkMessagePayload.user(from: m))
            }

        case CLIENTEVENT_CMD_USER_TEXTMSG:
            switch TeamTalkMessagePayload.textMessage(from: m).nMsgType {
            case MSGTYPE_CHANNEL:   playSound(.chan_MSG)
            case MSGTYPE_USER:      playSound(.user_MSG)
            case MSGTYPE_BROADCAST: playSound(.broadcast_MSG)
            default: break
            }

        default:
            break
        }
    }

    private func commandComplete(_ active_cmdid: INT32) {
        let cmd = channelListModel.activeCommands[active_cmdid]
        guard let cmd else { return }

        switch cmd {
        case .loginCmd:
            if !server.channel.isEmpty {
                var tokens = server.channel.components(separatedBy: "/").filter { !$0.isEmpty }
                let chanid = TeamTalkClient.shared.channelID(fromPath: server.channel)
                if chanid > 0 {
                    channelListModel.rejoinchannel.nChannelID = chanid
                    TeamTalkString.setChannel(.password, on: &channelListModel.rejoinchannel, to: server.chanpasswd)
                } else if tokens.count > 0 {
                    let channame = tokens.removeLast()
                    let chanpath = "/" + tokens.joined(separator: "/")
                    let parentid = TeamTalkClient.shared.channelID(fromPath: chanpath)
                    if parentid > 0 {
                        channelListModel.rejoinchannel.nParentID = parentid
                        TeamTalkString.setChannel(.name, on: &channelListModel.rejoinchannel, to: channame)
                        TeamTalkString.setChannel(.password, on: &channelListModel.rejoinchannel, to: server.chanpasswd)
                        channelListModel.rejoinchannel.audiocodec = newAudioCodec(DEFAULT_AUDIOCODEC)
                    }
                }
                server.channel.removeAll()
                server.chanpasswd.removeAll()
            }
            let statusMode = currentStatusMode()
            let statusMessage = currentStatusMessage()
            if statusMode != 0 || !statusMessage.isEmpty {
                TeamTalkClient.shared.changeStatus(mode: statusMode, message: statusMessage)
            }
        default:
            break
        }
    }

    private func login() {
        let nickname = server.nickname.isEmpty
            ? (UserDefaults.standard.string(forKey: PREF_GENERAL_NICKNAME) ?? "")
            : server.nickname
        cmdid = TeamTalkClient.shared.login(
            nickname: nickname,
            username: server.username,
            password: server.password,
            clientName: AppInfo.getAppName()
        )
        channelListModel.activeCommands[cmdid] = .loginCmd
        reconnecttimer?.invalidate()
    }
}
