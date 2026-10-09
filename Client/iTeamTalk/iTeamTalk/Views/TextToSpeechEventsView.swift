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

import Combine
import SwiftUI

struct TextToSpeechEventsView: View {
    private let rows = [
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_USERLOGIN, defaultValue: false, title: "User logged in", subtitle: "Announce user logged onto server"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_USERLOGOUT, defaultValue: false, title: "User logged out", subtitle: "Announce user logged out of server"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_JOINEDCHAN, defaultValue: true, title: "User joins channel", subtitle: "Announce user joining channel"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_LEFTCHAN, defaultValue: true, title: "User leaves channel", subtitle: "Announce user leaving channel"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_CONLOST, defaultValue: true, title: "Connection lost", subtitle: "Announce lost server connection"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_TEXTMSG, defaultValue: false, title: "Private Text Message", subtitle: "Announce content of text message"),
        TextToSpeechEventRow(preferenceKey: PREF_TTSEVENT_CHANTEXTMSG, defaultValue: false, title: "Channel Text Message", subtitle: "Announce content of text message")
    ]

    // what the announcements have in common, read again whenever one changes
    @State private var allEnabled = false
    @State private var allSpokenBy = SpokenBy.eachItsOwn

    var body: some View {
        Form {
            Section {
                Toggle("Enable All Announcements", isOn: Binding(
                    get: { allEnabled },
                    set: { setAll(enabled: $0) }
                ))
                Picker("Spoken By", selection: Binding(
                    get: { allSpokenBy },
                    set: { setAll(spokenBy: $0) }
                )) {
                    Text("VoiceOver").tag(SpokenBy.voiceOver)
                    Text("TeamTalk Voice").tag(SpokenBy.ownVoice)
                    if allSpokenBy == .eachItsOwn {
                        Text("Each One Its Own").tag(SpokenBy.eachItsOwn)
                    }
                }
            } header: {
                Text("All Announcements")
            } footer: {
                Text("These two settings change every announcement at once. Each one can still be set on its own below.")
            }
            Section {
                ForEach(rows) { row in
                    TextToSpeechEventToggle(row: row)
                }
            } header: {
                Text("Announcements")
            } footer: {
                Text("VoiceOver speaks an announcement with its own voice and shows it in braille. With VoiceOver off, the voice of TeamTalk speaks them all.")
            }
        }
        .navigationTitle("Text To Speech Events")
        .onAppear(perform: readAll)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)) { _ in
            readAll()
        }
    }

    private func readAll() {
        let defaults = UserDefaults.standard
        let enabled = rows.allSatisfy {
            defaults.object(forKey: $0.preferenceKey) == nil ? $0.defaultValue : defaults.bool(forKey: $0.preferenceKey)
        }
        let ownVoices = rows.filter { defaults.bool(forKey: $0.preferenceKey + PREF_TTSEVENT_OWNVOICE_SUFFIX) }.count
        let spokenBy: SpokenBy = ownVoices == 0 ? .voiceOver : ownVoices == rows.count ? .ownVoice : .eachItsOwn
        // only when they differ: writing them tells the view to draw again
        if enabled != allEnabled {
            allEnabled = enabled
        }
        if spokenBy != allSpokenBy {
            allSpokenBy = spokenBy
        }
    }

    private func setAll(enabled: Bool) {
        for row in rows {
            UserDefaults.standard.set(enabled, forKey: row.preferenceKey)
        }
        allEnabled = enabled
    }

    private func setAll(spokenBy: SpokenBy) {
        guard spokenBy != .eachItsOwn else { return }
        for row in rows {
            UserDefaults.standard.set(spokenBy == .ownVoice, forKey: row.preferenceKey + PREF_TTSEVENT_OWNVOICE_SUFFIX)
        }
        allSpokenBy = spokenBy
    }
}

/// Who speaks the announcements when they are set all at once
private enum SpokenBy: Hashable {
    case voiceOver
    case ownVoice
    case eachItsOwn
}

private struct TextToSpeechEventToggle: View {
    let row: TextToSpeechEventRow
    @AppStorage private var isOn: Bool
    @AppStorage private var ownVoice: Bool

    init(row: TextToSpeechEventRow) {
        self.row = row
        _isOn = AppStorage(wrappedValue: row.defaultValue, row.preferenceKey)
        _ownVoice = AppStorage(wrappedValue: false, row.preferenceKey + PREF_TTSEVENT_OWNVOICE_SUFFIX)
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                Text(row.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        if isOn {
            Picker("Spoken By", selection: $ownVoice) {
                Text("VoiceOver").tag(false)
                Text("TeamTalk Voice").tag(true)
            }
        }
    }
}

private struct TextToSpeechEventRow: Identifiable {
    let preferenceKey: String
    let defaultValue: Bool
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var id: String {
        preferenceKey
    }
}
