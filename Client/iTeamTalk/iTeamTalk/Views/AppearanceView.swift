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

struct AppearanceView: View {
    @ObservedObject private var appearance = AppearanceModel.shared

    var body: some View {
        Form {
            Section {
                ColorPicker("Received Messages", selection: $appearance.receivedColor, supportsOpacity: false)
                ColorPicker("Sent Messages", selection: $appearance.sentColor, supportsOpacity: false)
            } header: {
                Text("Text Messages")
            } footer: {
                Text("The text of a message is shown in black or white, whichever is easier to read on its color.")
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

            Section("Preview") {
                previewRow("Received message", color: appearance.receivedColor)
                previewRow("Sent message", color: appearance.sentColor)
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
                Button(action: appearance.restoreDefaults) {
                    Text("Restore Default Appearance")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Appearance")
    }

    private func previewRow(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .foregroundStyle(AppearanceModel.textColor(on: color))
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(color)
    }
}
