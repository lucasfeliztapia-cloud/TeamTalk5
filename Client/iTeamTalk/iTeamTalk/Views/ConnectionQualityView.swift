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
import TeamTalkKit

final class ConnectionQualityModel: ObservableObject {

    @Published var isConnected = false
    @Published var udpPing: INT32 = -1
    @Published var tcpPing: INT32 = -1
    @Published var voicePacketsReceived: Int64 = 0
    @Published var voicePacketsLost: Int64 = 0
    @Published var bytesSent: Int64 = 0
    @Published var bytesReceived: Int64 = 0

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        let client = TeamTalkClient.shared
        guard client.isConnected, let statistics = client.clientStatistics() else {
            isConnected = false
            return
        }

        isConnected = true
        udpPing = statistics.nUdpPingTimeMs
        tcpPing = statistics.nTcpPingTimeMs
        bytesSent = statistics.nUdpBytesSent
        bytesReceived = statistics.nUdpBytesRecv

        // packet loss is counted per user: add up the users of my channel
        var received: Int64 = 0
        var lost: Int64 = 0
        let channelID = client.myChannelID
        if channelID > 0 {
            for user in client.channelUsers(channelID: channelID) {
                if let userStatistics = client.userStatistics(userID: user.nUserID) {
                    received += userStatistics.nVoicePacketsRecv
                    lost += userStatistics.nVoicePacketsLost
                }
            }
        }
        voicePacketsReceived = received
        voicePacketsLost = lost
    }

    func pingText(_ ping: INT32) -> String {
        ping < 0
            ? String(localized: "No data", comment: "connection quality")
            : String(format: String(localized: "%d ms", comment: "connection quality"), Int(ping))
    }

    var lossText: String {
        let total = voicePacketsReceived + voicePacketsLost
        guard total > 0 else {
            return String(localized: "No data", comment: "connection quality")
        }
        let percent = Double(voicePacketsLost) * 100 / Double(total)
        return String(format: String(localized: "%.1f %% (%lld of %lld)", comment: "connection quality"),
                      percent, voicePacketsLost, total)
    }

    func dataText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

struct ConnectionQualityView: View {
    @StateObject private var model = ConnectionQualityModel()

    var body: some View {
        Form {
            if model.isConnected {
                Section {
                    LabeledContent("Voice Latency (UDP)", value: model.pingText(model.udpPing))
                    LabeledContent("Command Latency (TCP)", value: model.pingText(model.tcpPing))
                } header: {
                    Text("Latency")
                } footer: {
                    Text("Time a packet takes to reach the server and come back. Below 100 ms a conversation feels immediate.")
                }

                Section {
                    LabeledContent("Voice Packets Lost", value: model.lossText)
                } header: {
                    Text("Packet Loss")
                } footer: {
                    Text("Counted over the voice received from the users of your channel since you joined it. Above 2 % voices start to break up.")
                }

                Section("Data") {
                    LabeledContent("Sent", value: model.dataText(model.bytesSent))
                    LabeledContent("Received", value: model.dataText(model.bytesReceived))
                }
            } else {
                Text("Connect to a server to see the quality of the connection")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Connection Quality")
        .onAppear(perform: model.start)
        .onDisappear(perform: model.stop)
    }
}
