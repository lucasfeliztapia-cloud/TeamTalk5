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

struct AppearanceView: View {
    @ObservedObject private var appearance = AppearanceModel.shared
    @State private var sharedFile: SharedFile?
    @State private var showingImporter = false
    @State private var importFailed = false

    var body: some View {
        Form {
            Section {
                ColorPicker("Received Messages", selection: $appearance.receivedColor, supportsOpacity: false)
                ColorPicker("Sent Messages", selection: $appearance.sentColor, supportsOpacity: false)
                ColorPicker("Server Events", selection: $appearance.eventColor, supportsOpacity: false)
            } header: {
                Text("Text Messages")
            } footer: {
                Text("The text of a message is shown in black or white, whichever is easier to read on its color. Server events are what happens on the server, like someone joining or leaving the channel.")
            }

            Section {
                Picker("Text Size", selection: $appearance.textSizeIndex) {
                    Text("System Size").tag(0)
                    ForEach(1...AppearanceModel.textSizeTitles.count, id: \.self) { index in
                        Text(AppearanceModel.textSizeTitles[index - 1]).tag(index)
                    }
                }
                Picker("Font", selection: $appearance.fontDesign) {
                    ForEach(AppearanceFontDesign.allCases) { design in
                        Text(design.title).tag(design)
                    }
                }
            } header: {
                Text("Text")
            } footer: {
                Text("Size and font apply to the whole app.")
            }

            Section {
                Picker("Message Text Size", selection: $appearance.messageTextSizeIndex) {
                    Text("Same as the App").tag(0)
                    ForEach(1...AppearanceModel.textSizeTitles.count, id: \.self) { index in
                        Text(AppearanceModel.textSizeTitles[index - 1]).tag(index)
                    }
                }
                Picker("Font of Server Events", selection: $appearance.eventFontIndex) {
                    Text("Same as the App").tag(0)
                    ForEach(AppearanceFontDesign.allCases) { design in
                        Text(design.title).tag(design.rawValue + 1)
                    }
                }
            } header: {
                Text("Text of the Messages")
            } footer: {
                Text("The messages can have a text size of their own, and the server events a font of their own.")
            }

            Section("Preview") {
                previewRow("Received message", color: appearance.receivedColor)
                previewRow("Sent message", color: appearance.sentColor)
                previewRow("Server event", color: appearance.eventColor)
                    .modifier(FontDesignModifier(design: appearance.eventFontDesign))
            }
            .dynamicTypeSize(appearance.messageDynamicTypeRange)

            Section {
                ColorPicker("Not transmitting", selection: $appearance.talkIdleColor, supportsOpacity: false)
                ColorPicker("Transmitting", selection: $appearance.talkActiveColor, supportsOpacity: false)
                Button("Swap Talk Button Colors", action: appearance.swapTalkColors)
                buttonPreview
            } header: {
                Text("Talk Button")
            } footer: {
                Text("Color of the Talk button in each state. Its text is shown in black or white, whichever is easier to read.")
            }

            Section {
                ColorPicker("Listening", selection: $appearance.speakersOnColor, supportsOpacity: false)
                ColorPicker("Muted", selection: $appearance.speakersMutedColor, supportsOpacity: false)
                Button("Swap Speakers Button Colors", action: appearance.swapSpeakersColors)
                speakersPreview
            } header: {
                Text("Speakers Button")
            } footer: {
                Text("Color of the Speakers button in each state. Its icon is shown in black or white, whichever is easier to read.")
            }

            Section {
                ColorPicker("Interface Color", selection: Binding(
                    get: { appearance.interfaceColor ?? AppearanceModel.defaultInterfaceColor },
                    set: { appearance.interfaceColor = $0 }
                ), supportsOpacity: false)
            } header: {
                Text("Interface")
            } footer: {
                Text("Color of buttons, switches and the selected tab.")
            }

            Section {
                Picker("Light or Dark", selection: $appearance.colorSchemeIndex) {
                    Text("Same as the System").tag(0)
                    Text("Always Light").tag(1)
                    Text("Always Dark").tag(2)
                }
                Button("Apply High Contrast Theme", action: appearance.applyHighContrastTheme)
                Button("Apply Pure Dark Theme", action: appearance.applyPureDarkTheme)
            } header: {
                Text("Themes")
            } footer: {
                Text("A theme changes the colors above. You can adjust them afterwards.")
            }

            Section {
                Button("Export Appearance") {
                    if let url = appearance.exportFile() {
                        sharedFile = SharedFile(url: url)
                    }
                }
                Button("Import Appearance") {
                    showingImporter = true
                }
            } header: {
                Text("Share")
            } footer: {
                Text("Exports the colors, the text and the theme to a file that someone else can import.")
            }

            Section {
                Button(action: appearance.restoreDefaults) {
                    Text("Restore Default Appearance")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Appearance")
        .sheet(item: $sharedFile) { shared in
            ActivityView(items: [shared.url])
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json, .data]) { result in
            if case .success(let url) = result {
                importFailed = !appearance.importFile(url)
            }
        }
        .alert("Error", isPresented: $importFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This file is not an appearance exported from TeamTalk")
        }
    }

    /// The Talk button in its two states, side by side
    private var buttonPreview: some View {
        HStack(spacing: 8) {
            statePreview(Text("Not transmitting"), color: appearance.talkIdleColor)
            statePreview(Text("Transmitting"), color: appearance.talkActiveColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview")
    }

    /// The Speakers button in its two states, side by side
    private var speakersPreview: some View {
        HStack(spacing: 8) {
            statePreview(Image(systemName: "speaker.wave.2.fill"), color: appearance.speakersOnColor)
            statePreview(Image(systemName: "speaker.slash.fill"), color: appearance.speakersMutedColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview")
    }

    private func statePreview<Content: View>(_ content: Content, color: Color) -> some View {
        content
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(AppearanceModel.textColor(on: color))
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(color)
            .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
    }

    private func previewRow(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .foregroundStyle(AppearanceModel.textColor(on: color))
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(color)
    }
}
