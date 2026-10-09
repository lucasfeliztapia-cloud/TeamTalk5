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

struct SoundDevicesView: View {
    @StateObject private var model = SoundDevicesModel()
    @State private var microphoneMode = microphoneModeName(AVCaptureDevice.preferredMicrophoneMode)

    var body: some View {
        Form {
            Section("General") {
                ForEach(model.toggleRows) { row in
                    Toggle(isOn: Binding(
                        get: { model.preferenceValue(forKey: row.preferenceKey) },
                        set: { model.setPreference($0, forKey: row.preferenceKey) }
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

            Section {
                Picker("Voice Cleanup", selection: Binding(
                    get: { model.voiceCleanup },
                    set: { model.setVoiceCleanup($0) }
                )) {
                    Text("None").tag(0)
                    Text("iOS Voice Processing").tag(1)
                    Text("WebRTC").tag(2)
                }
            } header: {
                Text("Voice Cleanup")
            } footer: {
                Text("iOS voice processing cancels echo, reduces noise and levels the volume. WebRTC reduces noise and levels the volume but does not cancel echo, so use it with headphones.")
            }

            if model.voiceCleanup == 1 {
                Section {
                    LabeledContent("Microphone Mode", value: microphoneMode)
                    Button("Choose Microphone Mode") {
                        AVCaptureDevice.showSystemUserInterface(.microphoneModes)
                    }
                } header: {
                    Text("Microphone Mode")
                } footer: {
                    Text("Voice Isolation removes most of the sound around your voice. iOS lets you choose the mode while the microphone is in use, so join a channel first.")
                }
            }

            Section {
                Button(action: model.toggleMicrophoneTest) {
                    Group {
                        if model.isTestingMicrophone {
                            Text("Stop Microphone Test")
                        } else {
                            Text("Test Microphone")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!model.canTestMicrophone && !model.isTestingMicrophone)
            } header: {
                Text("Microphone Test")
            } footer: {
                Text("You will hear your own microphone. Use headphones, or the speaker will be picked up again. Only available while you are not in a channel.")
            }

            ForEach(model.audioInputSections) { section in
                Section(section.title) {
                    ForEach(section.dataSources.indices, id: \.self) { index in
                        Button {
                            model.selectDataSource(at: index, for: section.input)
                        } label: {
                            Text(model.title(for: section.dataSources, at: index, input: section.input))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Setup Sound Devices")
        // the mode is chosen in Control Center: read it again on the way back
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            microphoneMode = microphoneModeName(AVCaptureDevice.preferredMicrophoneMode)
        }
        .onDisappear(perform: model.stopMicrophoneTest)
    }
}
