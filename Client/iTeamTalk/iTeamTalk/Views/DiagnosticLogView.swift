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

struct DiagnosticLogView: View {
    @ObservedObject private var log = DiagnosticLog.shared
    @State private var sharedFile: SharedFile?

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
        .sheet(item: $sharedFile) { shared in
            ActivityView(items: [shared.url])
        }
    }
}
