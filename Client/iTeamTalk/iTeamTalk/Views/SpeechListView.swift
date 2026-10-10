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

struct SpeechListView: View {
    // Read once and away from the main thread. Asking the system for its
    // voices is slow, and it was asked once per language every time the list
    // was drawn: with VoiceOver on, entering the screen or choosing a voice
    // held everything for seconds.
    @State private var sections = [SpeechVoiceSection]()
    @State private var isLoading = true
    @State private var selectedVoiceIdentifier = UserDefaults.standard.string(forKey: PREF_TTSEVENT_VOICEID)

    var body: some View {
        List {
            ForEach(sections) { section in
                Section(section.language) {
                    ForEach(section.voices) { voice in
                        Button {
                            select(voice)
                        } label: {
                            LabeledContent {
                                if selectedVoiceIdentifier == voice.id {
                                    Text("Selected")
                                        .foregroundStyle(.secondary)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(voice.name)
                                    if let name = section.localName {
                                        Text(name)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .navigationTitle("Text-to-Speech Voice")
        .task {
            guard sections.isEmpty else { return }
            sections = await Task.detached(priority: .userInitiated) {
                SpeechVoiceSection.all()
            }.value
            isLoading = false
        }
    }

    private func select(_ voice: SpeechVoice) {
        selectedVoiceIdentifier = voice.id
        UserDefaults.standard.setValue(voice.id, forKey: PREF_TTSEVENT_VOICEID)

        // said by the voice itself: with VoiceOver on it was VoiceOver that
        // read it, and the chosen voice was never heard
        let utterance = String(format: String(localized: "You have selected %@", comment: "speech"), voice.name)
        speakSample(utterance, after: 0.6)
    }
}

private struct SpeechVoice: Identifiable, Sendable {
    let id: String
    let name: String
}

private struct SpeechVoiceSection: Identifiable, Sendable {
    let language: String
    let localName: String?
    let voices: [SpeechVoice]

    var id: String {
        language
    }

    /// Every voice of the system by language, the language of the device first
    static func all() -> [SpeechVoiceSection] {
        let current = AVSpeechSynthesisVoice.currentLanguageCode()
        var languages = [current]
        var voices = [String: [SpeechVoice]]()
        for voice in AVSpeechSynthesisVoice.speechVoices() {
            if voices[voice.language] == nil && voice.language != current {
                languages.append(voice.language)
            }
            voices[voice.language, default: []].append(SpeechVoice(id: voice.identifier, name: voice.name))
        }
        let locale = Locale.current as NSLocale
        return languages.map { language in
            SpeechVoiceSection(
                language: language,
                localName: locale.displayName(forKey: NSLocale.Key.identifier, value: language),
                voices: voices[language] ?? []
            )
        }
    }
}
