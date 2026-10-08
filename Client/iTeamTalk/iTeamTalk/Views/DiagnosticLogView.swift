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
import UIKit

struct DiagnosticLogView: View {
    @ObservedObject private var log = DiagnosticLog.shared
    @State private var sharedFile: SharedFile?
    @State private var check = SystemCheck.current()
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Button {
                    if let url = log.exportFile() {
                        sharedFile = SharedFile(url: url)
                    }
                } label: {
                    Label("Share Log", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive, action: log.clear) {
                    Label("Clear Log", systemImage: "trash")
                }
            } footer: {
                Text("The log records what the app does: connection, sound devices, transfers and errors. It holds no passwords and nothing of what is said or written.")
            }

            Section {
                checkRow("Microphone", value: microphoneText, isFine: check.microphone != .denied)
                checkRow("Live Activities", value: liveActivitiesText, isFine: check.liveActivities == .available)
                checkRow("Widget and Controls", value: appGroupText, isFine: check.hasAppGroup)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            } header: {
                Text("Checks")
            } footer: {
                Text("What the app needs from the iPhone. If something here is not right, it is the first thing to fix.")
            }

            Section {
                Text(log.header)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }

            Section {
                if log.lines.isEmpty {
                    Text("The log is empty")
                        .foregroundStyle(.secondary)
                }
                // newest first: it is what one came to look for
                ForEach(Array(log.lines.enumerated().reversed()), id: \.offset) { entry in
                    Text(entry.element)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            } header: {
                Text(verbatim: String(format: String(localized: "%d entries", comment: "diagnostics"), log.lines.count))
            }
        }
        .navigationTitle("Diagnostics")
        .onAppear {
            check = SystemCheck.current()
        }
        .sheet(item: $sharedFile) { shared in
            ActivityView(items: [shared.url])
        }
    }

    private func checkRow(_ title: LocalizedStringKey, value: String, isFine: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: isFine ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(isFine ? Color.green : Color.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(verbatim: value)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var microphoneText: String {
        switch check.microphone {
        case .granted:
            return String(localized: "Allowed", comment: "diagnostics")
        case .denied:
            return String(localized: "Not allowed. Nobody can hear you until you turn it on in Settings, under TeamTalk.", comment: "diagnostics")
        case .undetermined:
            return String(localized: "Not asked yet. iOS asks the first time you join a channel.", comment: "diagnostics")
        }
    }

    private var liveActivitiesText: String {
        switch check.liveActivities {
        case .available:
            return String(localized: "Available", comment: "diagnostics")
        case .disabled:
            return String(localized: "Turned off. Turn on Live Activities in Settings, under TeamTalk.", comment: "diagnostics")
        case .notInstalled:
            return String(localized: "Not installed. The app was installed without its extension, so there are no Live Activities, widget or controls. Install it again with a tool that keeps the extensions.", comment: "diagnostics")
        case .unsupported:
            return String(localized: "They need iOS 17 or later", comment: "diagnostics")
        }
    }

    private var appGroupText: String {
        check.hasAppGroup
            ? String(localized: "Available", comment: "diagnostics")
            : String(localized: "Not available with this installation. The widget cannot show your servers and the controls do not show their state.", comment: "diagnostics")
    }
}
