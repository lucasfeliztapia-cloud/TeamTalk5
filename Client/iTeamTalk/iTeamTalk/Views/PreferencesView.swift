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
import SwiftUI
import TeamTalkKit
import UniformTypeIdentifiers

struct PreferencesView: View {
    @ObservedObject var model: PreferencesModel
    @State private var backupFile: SharedFile?
    @State private var showingBackupImporter = false
    @State private var backupMessage: String?
    @AppStorage(PREF_DISPLAY_MSGDETAILS) private var messageDetails = MessageDetails.nameAndTime.rawValue
    @AppStorage(PREF_DISPLAY_MSGDETAILSAFTER) private var messageDetailsAfter = false
    @AppStorage(PREF_GENERAL_CONFIRMDISCONNECT) private var confirmDisconnect = false
    @AppStorage(PREF_DISPLAY_MSGFOCUS) private var followsNewMessages = false
    @AppStorage(PREF_NOTIFY_BACKGROUND) private var notifyInBackground = false
    @AppStorage(PREF_NOTIFY_USERMSG) private var notifyUserMessages = true
    @AppStorage(PREF_NOTIFY_CHANMSG) private var notifyChannelMessages = false
    @AppStorage(PREF_NOTIFY_BROADCAST) private var notifyBroadcastMessages = true
    @State private var notificationsDenied = false
    @FocusState private var writtenField: WrittenField?

    private enum WrittenField: Hashable {
        case nickname, statusMessage
    }

    var body: some View {
        Form {
            generalSection
            displaySection
            appearanceSection
            soundSection
            soundEventsSection
            ttsSection
            notificationsSection
            connectionSection
            subscriptionsSection
            backupSection
            versionSection
        }
        .navigationTitle("Preferences")
        // what is written goes to the server when the field is left
        .onChange(of: writtenField) { _ in
            model.applyNickname()
            model.applyStatusMessage()
        }
        .onDisappear {
            model.applyNickname()
            model.applyStatusMessage()
        }
        .sheet(item: $backupFile) { shared in
            ActivityView(items: [shared.url])
        }
        .fileImporter(isPresented: $showingBackupImporter, allowedContentTypes: [.data]) { result in
            guard case .success(let url) = result else { return }
            backupMessage = SettingsBackup.importFile(url)
                ? String(localized: "Backup restored. Close the app and open it again to apply every setting.", comment: "backup")
                : String(localized: "This file is not a TeamTalk backup", comment: "backup")
        }
        .alert("Backup", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupMessage ?? "")
        }
        .alert("Notifications", isPresented: $notificationsDenied) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("TeamTalk is not allowed to show notifications. Turn them on in Settings, under TeamTalk.")
        }
    }

    // MARK: - An explanation for each choice

    private var genderExplanation: LocalizedStringKey {
        switch model.genderIndex {
        case 1:
            return "Other users see you with the female icon"
        case 2:
            return "Other users see you with the neutral icon"
        default:
            return "Other users see you with the male icon"
        }
    }

    private var statusExplanation: LocalizedStringKey {
        switch model.statusIndex {
        case 1:
            return "Other users see you as away"
        case 2:
            return "Other users see that you have a question"
        default:
            return "Other users see you as available"
        }
    }

    private var messageDetailsExplanation: LocalizedStringKey {
        switch MessageDetails(rawValue: messageDetails) ?? .nameAndTime {
        case .nameAndTime:
            return "Each message shows who sent it and when"
        case .nameOnly:
            return "Each message shows who sent it"
        case .timeOnly:
            return "Each message shows when it was sent, and the name heads each group of messages"
        case .messageOnly:
            return "Each message shows its text alone, and the name heads each group of messages"
        }
    }

    private var detailsPositionExplanation: LocalizedStringKey {
        messageDetailsAfter
            ? "The name and the time go after the text of the message"
            : "The name and the time go before the text of the message"
    }

    private var messageFocusExplanation: LocalizedStringKey {
        followsNewMessages
            ? "VoiceOver moves to each message as it arrives or as you send it"
            : "VoiceOver stays on the message you are reading when another one arrives"
    }

    private var channelSortExplanation: LocalizedStringKey {
        model.channelSortIndex == 0
            ? "Channels are sorted by name"
            : "Channels are sorted by the number of users in them"
    }

    private var sortDirectionExplanation: LocalizedStringKey {
        switch (model.channelSortIndex == 0, model.channelSortDescending) {
        case (true, false):
            return "From A to Z"
        case (true, true):
            return "From Z to A"
        case (false, false):
            return "From fewer users to more"
        case (false, true):
            return "From more users to fewer"
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle(isOn: Binding(get: { notifyInBackground }, set: { setNotifications($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications in the Background")
                    Text("Show a notification when a text message arrives while the app is not in front")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if notifyInBackground {
                Toggle("User Messages", isOn: $notifyUserMessages)
                Toggle("Channel Messages", isOn: $notifyChannelMessages)
                Toggle("Broadcast Messages", isOn: $notifyBroadcastMessages)
            }
        }
    }

    /// iOS asks for its permission the first time. Refused, the switch goes
    /// back: on and silent would be worse than off.
    private func setNotifications(_ enabled: Bool) {
        guard enabled else {
            notifyInBackground = false
            return
        }
        TextMessageNotifications.requestPermission { granted in
            notifyInBackground = granted
            notificationsDenied = !granted
        }
    }

    private var generalSection: some View {
        Section("General") {
            VStack(alignment: .leading, spacing: 4) {
                LabeledContent {
                    TextField("", text: Binding(
                        get: { model.nicknameText },
                        set: { model.nicknameChanged($0) }
                    ))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($writtenField, equals: .nickname)
                    .onSubmit {
                        model.applyNickname()
                    }
                    .accessibilityLabel(Text("Nickname"))
                } label: {
                    Text("Nickname")
                }
                PreferenceSubtitle("Name displayed in channel list")
                if let note = model.nicknameNote {
                    PreferenceSubtitle(verbatim: note)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gender")
                    Picker("Gender", selection: Binding(
                        get: { model.genderIndex },
                        set: { model.genderChanged($0) }
                    )) {
                        Text("Male").tag(0)
                        Text("Female").tag(1)
                        Text("Neutral").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                PreferenceSubtitle(genderExplanation)
            }

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Status")
                    Picker("Status", selection: Binding(
                        get: { model.statusIndex },
                        set: { model.statusChanged($0) }
                    )) {
                        Text("Available").tag(0)
                        Text("Away").tag(1)
                        Text("Question").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                PreferenceSubtitle(statusExplanation)
                if let note = model.statusNote {
                    PreferenceSubtitle(verbatim: note)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                LabeledContent {
                    TextField("", text: Binding(
                        get: { model.statusMessage },
                        set: { model.statusMessageChanged($0) }
                    ))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .submitLabel(.done)
                    .focused($writtenField, equals: .statusMessage)
                    .onSubmit {
                        model.applyStatusMessage()
                    }
                    .accessibilityLabel(Text("Status Message"))
                } label: {
                    Text("Status Message")
                }
                PreferenceSubtitle("Text shown next to your name")
            }

            NavigationLink {
                WebLoginView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BearWare.dk Web Login")
                    Text("Login ID from BearWare.dk")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: Binding(get: { model.pushToTalkLock }, set: { model.pttlockChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Push To Talk Lock")
                    Text("Double tap to lock TX button")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { model.headsetTXToggle }, set: { model.headsetTxToggleChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Headset TX Toggle")
                    Text("Toggle voice transmission using headset")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { model.sendOnReturn }, set: { model.sendonenterChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Return Sends Message")
                    Text("Pressing Return-key sends text message")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                KeyboardShortcutsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keyboard Shortcuts")
                    Text("Keys of an external keyboard to talk and to mute")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Toggle(isOn: Binding(get: { model.proximitySensor }, set: { model.proximityChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proximity Sensor")
                    Text("Turn off screen when holding phone near ear")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { model.popupTextMessages }, set: { model.showtextmessagesChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Text Messages Instantly")
                    Text("Pop up text message when new messages are received")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            messageDetailRows
            maximumTextLengthRow
            NavigationLink {
                PublicServerView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Filter Server List")
                    Text("Limit types of servers to show")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { model.showUsername }, set: { model.showusernameChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Usernames")
                    Text("Show usernames instead of nicknames")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            channelSortRows
        }
    }

    /// What a message shows besides its text, and on which side of it
    @ViewBuilder
    private var messageDetailRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Message Details", selection: $messageDetails) {
                Text("Name and Time").tag(MessageDetails.nameAndTime.rawValue)
                Text("Name Only").tag(MessageDetails.nameOnly.rawValue)
                Text("Time Only").tag(MessageDetails.timeOnly.rawValue)
                Text("Message Only").tag(MessageDetails.messageOnly.rawValue)
            }
            PreferenceSubtitle(messageDetailsExplanation)
        }
        VStack(alignment: .leading, spacing: 4) {
            Picker("Details Position", selection: $messageDetailsAfter) {
                Text("Before the Message").tag(false)
                Text("After the Message").tag(true)
            }
            PreferenceSubtitle(detailsPositionExplanation)
        }
        VStack(alignment: .leading, spacing: 4) {
            Picker("When a Message Arrives", selection: $followsNewMessages) {
                Text("Keep the Position").tag(false)
                Text("Go to the Newest Message").tag(true)
            }
            PreferenceSubtitle(messageFocusExplanation)
        }
    }

    /// A slider between the two buttons: the buttons go one by one, the
    /// slider crosses the whole range.
    private var maximumTextLengthRow: some View {
        let range = 1...Double(TT_STRLEN - 1)
        let length = Int(model.limitText.rounded())

        return VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Maximum Text Length")
                    Spacer(minLength: 16)
                    Text(verbatim: "\(length)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                // the slider says both
                .accessibilityHidden(true)
                HStack(spacing: 12) {
                    Button {
                        model.limittextChanged(max(range.lowerBound, model.limitText - 1))
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Decrement"))
                    AdjustableSlider(label: Text("Maximum Text Length"), valueText: "\(length)",
                                     value: Binding(get: { model.limitText }, set: { model.limittextChanged($0) }),
                                     range: range, step: 1)
                    Button {
                        model.limittextChanged(min(range.upperBound, model.limitText + 1))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(Text("Increment"))
                }
            }
            PreferenceSubtitle(verbatim: String(format: String(localized: "Limit length of names in channel list to %d characters", comment: "preferences"), length))
        }
    }

    /// What the channels are sorted by, and in which direction
    @ViewBuilder
    private var channelSortRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort Channels")
                Picker("Sort Channels", selection: Binding(
                    get: { model.channelSortIndex },
                    set: { model.channelSortChanged($0) }
                )) {
                    Text("Name").tag(0)
                    Text("Number of Users").tag(1)
                }
                .pickerStyle(.segmented)
            }
            PreferenceSubtitle(channelSortExplanation)
        }
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sort Direction")
                Picker("Sort Direction", selection: Binding(
                    get: { model.channelSortDescending },
                    set: { model.channelSortDirectionChanged($0) }
                )) {
                    Text("Ascending").tag(false)
                    Text("Descending").tag(true)
                }
                .pickerStyle(.segmented)
            }
            PreferenceSubtitle(sortDirectionExplanation)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            NavigationLink {
                AppearanceView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Colors and Text")
                    Text("Choose colors, text size and font")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var soundSection: some View {
        Section("Sound System") {
            sliderWithSubtitle(
                title: "Master Volume",
                subtitle: Text(verbatim: model.percentSubtitle(model.masterVolumePercent)),
                value: Binding(get: { model.masterVolumePercent }, set: { model.masterVolumeChanged($0) }),
                range: 0...100,
                step: 1,
                displayValue: { model.percentSubtitle($0) }
            )
            sliderWithSubtitle(
                title: "Media File Volume",
                subtitle: Text("Media file vs. voice volume"),
                value: Binding(get: { model.mediaFileVolumePercent }, set: { model.mediafileVolumeChanged($0) }),
                range: 0...100,
                step: 1,
                hint: Text("Media file vs. voice volume"),
                displayValue: { "\(Int($0.rounded())) %" }
            )
            sliderWithSubtitle(
                title: "Microphone Gain",
                subtitle: Text(verbatim: model.percentSubtitle(model.microphoneGainPercent)),
                value: Binding(get: { model.microphoneGainPercent }, set: { model.microphoneGainChanged($0) }),
                range: 0...100,
                step: 1,
                displayValue: { model.percentSubtitle($0) }
            )
            sliderWithSubtitle(
                title: "Voice Activation Level",
                subtitle: Text(verbatim: model.voiceActivationSubtitle(model.voiceActivationLevel)),
                value: Binding(get: { model.voiceActivationLevel }, set: { model.voiceactlevelChanged($0) }),
                range: 0...Double(VOICEACT_DISABLED),
                step: 1,
                readsSubtitle: true,
                displayValue: { model.voiceActivationValueText($0) }
            )
            NavigationLink {
                SoundDevicesView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup Sound Devices")
                    Text("Choose input and output devices")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var soundEventsSection: some View {
        Section("Sound Events") {
            NavigationLink {
                SoundEventsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup Sound Events")
                    Text("Choose sounds events to play")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ttsSection: some View {
        Section("Text To Speech Events") {
            NavigationLink {
                SpeechListView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speech")
                    Text("Select the text-to-speech voice to use")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            sliderWithSubtitle(
                title: "Speech Rate",
                subtitle: Text(verbatim: String(format: String(localized: "The rate of the speaking voice is %.1f", comment: "preferences"), Float(model.ttsRate))),
                value: Binding(get: { model.ttsRate }, set: { model.ttsrateChanged($0) }),
                range: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate),
                step: 0.1,
                displayValue: { String(format: "%.1f", $0) }
            )
            sliderWithSubtitle(
                title: "Speech Volume",
                subtitle: Text(verbatim: String(format: String(localized: "The volume of the speaking voice is %.1f", comment: "preferences"), Float(model.ttsVolume))),
                value: Binding(get: { model.ttsVolume }, set: { model.ttsvolChanged($0) }),
                range: 0...1,
                step: 0.1,
                displayValue: { String(format: "%.1f", $0) }
            )
            NavigationLink {
                TextToSpeechEventsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Setup Announcements")
                    Text("Choose events to playback")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            Toggle(isOn: Binding(get: { model.joinRoot }, set: { model.joinrootChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Join Root Channel")
                    Text("Join root channel after login")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $confirmDisconnect) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confirm Before Disconnecting")
                    Text("Ask before leaving the server")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { model.connectLastServer }, set: { model.connectLastServerChanged($0) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect on Startup")
                    Text("Connect to the last server and channel when the app opens")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink {
                ConnectionQualityView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connection Quality")
                    Text("Latency and packet loss")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button("Export Settings and Servers") {
                if let url = SettingsBackup.exportFile() {
                    backupFile = SharedFile(url: url)
                }
            }
            Button("Import Backup") {
                showingBackupImporter = true
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("The backup holds every setting and the list of servers, with their passwords. Keep the file somewhere safe.")
        }
    }

    private var subscriptionsSection: some View {
        Section("Default Subscriptions") {
            ForEach(model.subscriptionRows) { row in
                Toggle(isOn: Binding(
                    get: { model.isSubscribed(to: row) },
                    set: { model.subscriptionChanged($0, row: row) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                        Text(row.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var versionSection: some View {
        Section("Version Information") {
            ForEach(model.versionRows) { row in
                LabeledContent(row.title, value: row.value)
            }
        }
    }

    /// For VoiceOver the row is the slider alone, with the title as its label
    /// and its value said once. As one combined element the value was read
    /// three or four times, from the text, the slider and the subtitle, and
    /// "double tap and hold" could not take hold of the thumb.
    /// `readsSubtitle` keeps the subtitle for VoiceOver when it says more than
    /// the value.
    private func sliderWithSubtitle(title: LocalizedStringKey,
                                    subtitle: Text,
                                    value: Binding<Double>,
                                    range: ClosedRange<Double>,
                                    step: Double,
                                    hint: Text? = nil,
                                    readsSubtitle: Bool = false,
                                    displayValue: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(title)
                    Spacer(minLength: 16)
                    Text(displayValue(value.wrappedValue))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
                AdjustableSlider(label: Text(title), valueText: displayValue(value.wrappedValue),
                                 value: value, range: range, step: step, hint: hint)
            }
            PreferenceSubtitle(subtitle)
                .accessibilityHidden(!readsSubtitle)
        }
    }
}

/// A slider VoiceOver can drag as well as flick. It is an element of its own
/// with one label and one value, and the point where VoiceOver touches it is
/// on the thumb, so "double tap and hold" takes hold of it and the finger
/// moves it step by step. A flick up or down moves it one step too.
struct AdjustableSlider: View {
    let label: Text
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var hint: Text?

    var body: some View {
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? min(1, max(0, (value - range.lowerBound) / span)) : 0

        Slider(value: $value, in: range, step: step)
            .accessibilityLabel(label)
            .accessibilityValue(Text(verbatim: valueText))
            .accessibilityHint(hint ?? Text(verbatim: ""))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(range.upperBound, value + step)
                case .decrement:
                    value = max(range.lowerBound, value - step)
                @unknown default:
                    break
                }
            }
            // the thumb stops half its width short of each end of the track
            .accessibilityActivationPoint(UnitPoint(x: 0.05 + 0.9 * fraction, y: 0.5))
    }
}

struct PreferenceSubtitle: View {
    let text: Text

    init(_ text: LocalizedStringKey) {
        self.text = Text(text)
    }

    init(verbatim text: String) {
        self.text = Text(verbatim: text)
    }

    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}
