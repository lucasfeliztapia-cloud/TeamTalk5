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

import SwiftUI
import UniformTypeIdentifiers

struct MediaStreamView: View {
    @ObservedObject var model: MediaStreamModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileImporter = false

    var body: some View {
        Form {
            Section("Media File") {
                Button {
                    showingFileImporter = true
                } label: {
                    LabeledContent("File",
                                   value: model.hasFile
                                       ? model.fileName
                                       : String(localized: "Choose a file", comment: "media stream"))
                }
                .buttonStyle(.plain)
                .disabled(model.isPreparing)

                if model.hasFile {
                    LabeledContent("Duration", value: model.durationText)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Duration")
                        .accessibilityValue(MediaStreamModel.spokenText(model.durationMSec))

                    if model.hasVideo {
                        Toggle("Send Video", isOn: $model.sendVideo)
                            .disabled(!model.canStreamVideo || model.isStreaming)
                    }
                }
            }

            if model.hasFile {
                Section("Position") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text(model.positionText)
                            Spacer(minLength: 16)
                            Text(model.durationText)
                        }
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                        Slider(
                            value: Binding(
                                get: { model.positionMSec },
                                set: { model.setPosition($0) }
                            ),
                            in: 0...max(1000, model.durationMSec)
                        )
                        .accessibilityLabel("Position")
                        .accessibilityValue(model.spokenPositionText)
                    }

                    Button("Back 1 Minute") {
                        model.skip(seconds: -60)
                    }
                    Button("Back 10 Seconds") {
                        model.skip(seconds: -10)
                    }
                    Button("Forward 10 Seconds") {
                        model.skip(seconds: 10)
                    }
                    Button("Forward 1 Minute") {
                        model.skip(seconds: 60)
                    }
                }
            }

            Section {
                if model.isStreaming {
                    Button(action: model.togglePause) {
                        Group {
                            if model.state == .paused {
                                Text("Resume")
                            } else {
                                Text("Pause")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    Button(role: .destructive, action: model.stop) {
                        Text("Stop Streaming")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    Button(action: model.start) {
                        Text("Start Streaming")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(!model.canStart)
                }
            } header: {
                Text("Controls")
            } footer: {
                Text(model.statusText)
            }
        }
        .navigationTitle("Stream Media File")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    model.selectFile(url)
                }
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
