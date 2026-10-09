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
    @State private var showingWebAddress = false
    @State private var webAddress = ""

    var body: some View {
        Form {
            controlsSection
            if model.hasFile {
                if !model.isLive {
                    positionSection
                }
                soundSection
            }
            playlistSection
        }
        .navigationTitle("Stream Media File")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.audio, .movie],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                model.addFiles(urls)
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .alert("Web Address", isPresented: $showingWebAddress) {
            TextField("https://", text: $webAddress)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Add") {
                model.addWebAddress(webAddress)
                webAddress = ""
            }
            Button("Cancel", role: .cancel) {
                webAddress = ""
            }
        } message: {
            Text("Address of a web radio or of an audio or video file")
        }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .onDisappear(perform: model.stopPreview)
    }

    // MARK: - Controls

    private var controlsSection: some View {
        Section {
            if model.hasFile {
                LabeledContent("File", value: model.fileName)
            }

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

            if model.items.count > 1 {
                Button(action: model.playPrevious) {
                    Text("Previous File")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!model.hasPrevious)
                Button(action: model.playNext) {
                    Text("Next File")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!model.hasNext)
            }
        } header: {
            Text("Controls")
        } footer: {
            Text(model.statusText)
        }
    }

    // MARK: - Position

    private var positionSection: some View {
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
                // on the thumb, so VoiceOver can drag it
                .accessibilityActivationPoint(UnitPoint(
                    x: 0.05 + 0.9 * min(1, max(0, model.positionMSec / max(1000, model.durationMSec))),
                    y: 0.5
                ))
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

    // MARK: - Sound

    private var soundSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text("Volume")
                    Spacer(minLength: 16)
                    Text(model.volumeText)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)

                AdjustableSlider(label: Text("Volume"), valueText: model.volumeText,
                                 value: $model.volumePercent, range: 0...300, step: 1, flick: 10)
            }

            Button(action: model.togglePreview) {
                Group {
                    if model.isPreviewing {
                        Text("Stop Preview")
                    } else {
                        Text("Preview")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .disabled(model.isStreaming)

            if model.hasVideo {
                Toggle("Send Video", isOn: $model.sendVideo)
                    .disabled(!model.canStreamVideo || model.isStreaming)
            }
        } header: {
            Text("Sound")
        } footer: {
            Text("100 % leaves the file as it is. The preview plays on this device only, with this volume and from the chosen position.")
        }
    }

    // MARK: - Playlist

    private var playlistSection: some View {
        Section {
            ForEach(model.items) { item in
                playlistRow(item)
            }
            .onDelete { offsets in
                model.remove(at: offsets)
            }
            .onMove { source, destination in
                model.move(from: source, to: destination)
            }

            Button {
                showingFileImporter = true
            } label: {
                Label("Add Files", systemImage: "plus")
            }
            .disabled(model.isPreparing)

            Button {
                showingWebAddress = true
            } label: {
                Label("Add Web Address", systemImage: "globe")
            }
            .disabled(model.isPreparing)

            Picker("Repeat", selection: $model.repeatMode) {
                ForEach(StreamRepeat.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } header: {
            Text("Playlist")
        } footer: {
            Text("Files stay in the list until you remove them. When one ends, the next one starts.")
        }
    }

    private func playlistRow(_ item: StreamItem) -> some View {
        let isCurrent = item.id == model.currentID

        return Button {
            model.select(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.isWeb ? "globe" : (item.hasVideo ? "film" : "music.note"))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(model.detail(for: item))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue(model.spokenDetail(for: item))
        .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
    }
}
