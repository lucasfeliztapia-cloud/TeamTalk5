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

// MARK: - All users

/// Every user the server lets this account see, to find someone on a large server
struct AllUsersView: View {
    @ObservedObject var model: ChannelListModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var users: [User] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return model.users.values
            .filter {
                query.isEmpty ||
                    getDisplayName($0).range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            .sorted {
                getDisplayName($0).caseInsensitiveCompare(getDisplayName($1)) == .orderedAscending
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(users, id: \.nUserID) { user in
                        row(user)
                    }
                } footer: {
                    Text("Choosing a user shows the channel they are in. If the server does not let your account see all users, only those of your channel are listed.")
                }
            }
            .searchable(text: $searchText, prompt: "Search users")
            .navigationTitle("All Users")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func row(_ user: User) -> some View {
        Button {
            if user.nChannelID > 0 {
                model.goToChannel(id: user.nChannelID)
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(getDisplayName(user))
                    .foregroundStyle(.primary)
                Text(model.channelText(for: user))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            if user.nChannelID > 0 && user.nChannelID != model.mychannel.nChannelID {
                Button {
                    model.joinChannelFromAccessibility(channelID: user.nChannelID)
                    dismiss()
                } label: {
                    Label("Join Their Channel", systemImage: "arrow.right.circle")
                }
                .tint(.green)
            }
            if model.canMoveUsers && model.mychannel.nChannelID > 0 && user.nChannelID != model.mychannel.nChannelID {
                Button {
                    model.moveUsers([user.nUserID], to: model.mychannel.nChannelID)
                } label: {
                    Label("Bring to My Channel", systemImage: "arrow.down.left.circle")
                }
                .tint(.orange)
            }
            Button {
                dismiss()
                model.showTextMessages(userid: user.nUserID)
            } label: {
                Label("Private Message", systemImage: "message")
            }
            .tint(.blue)
        }
    }
}

// MARK: - Who can transmit

struct TransmitStream: Identifiable {
    let id: UInt32
    let title: LocalizedStringKey
}

let transmitStreams = [
    TransmitStream(id: STREAMTYPE_VOICE.rawValue, title: "Voice"),
    TransmitStream(id: STREAMTYPE_MEDIAFILE.rawValue, title: "Media Files"),
    TransmitStream(id: STREAMTYPE_CHANNELMSG.rawValue, title: "Channel Messages"),
    TransmitStream(id: STREAMTYPE_VIDEOCAPTURE.rawValue, title: "WebCam"),
    TransmitStream(id: STREAMTYPE_DESKTOP.rawValue, title: "Desktop")
]

/// What each user of the channel is allowed to send to it
struct TransmitControlView: View {
    @ObservedObject var model: ChannelListModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.isClassroom {
                        Text("This is a classroom channel: only what is turned on here can be transmitted.")
                    } else {
                        Text("Everyone can transmit in this channel except what is turned off here.")
                    }
                }

                if model.isClassroom {
                    Section("Everyone") {
                        toggles(for: TeamTalkTransmitUsers.freeForAll)
                    }
                }

                ForEach(model.usersInMyChannel, id: \.nUserID) { user in
                    Section(getDisplayName(user)) {
                        toggles(for: user.nUserID)
                    }
                }
            }
            .navigationTitle("Who Can Transmit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
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

    private func toggles(for userID: INT32) -> some View {
        ForEach(transmitStreams) { stream in
            Toggle(stream.title, isOn: Binding(
                get: { model.mayTransmit(userID: userID, stream: stream.id) },
                set: { model.setMayTransmit(userID: userID, stream: stream.id, allowed: $0) }
            ))
        }
    }
}

// MARK: - Banned users

struct BanEntry: Identifiable {
    let id = UUID()
    let banned: BannedUser
    let nickname: String
    let username: String
    let ipAddress: String
    let channelPath: String
    let banTime: String
    let owner: String

    init(_ banned: BannedUser) {
        self.banned = banned
        nickname = TeamTalkString.bannedUser(.nickname, from: banned)
        username = TeamTalkString.bannedUser(.username, from: banned)
        ipAddress = TeamTalkString.bannedUser(.ipAddress, from: banned)
        channelPath = TeamTalkString.bannedUser(.channelPath, from: banned)
        banTime = TeamTalkString.bannedUser(.banTime, from: banned)
        owner = TeamTalkString.bannedUser(.owner, from: banned)
    }

    var title: String {
        if !nickname.isEmpty {
            return nickname
        }
        if !username.isEmpty {
            return username
        }
        return ipAddress
    }
}

final class BanListModel: ObservableObject, TeamTalkEvent {

    @Published var entries = [BanEntry]()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listCommand: INT32 = 0
    private var unbanCommands = [INT32: UUID]()

    func load() {
        entries = []
        listCommand = TeamTalkClient.shared.listBans()
        isLoading = listCommand > 0
    }

    func unban(_ entry: BanEntry) {
        let cmdid = TeamTalkClient.shared.unban(entry.banned)
        if cmdid > 0 {
            unbanCommands[cmdid] = entry.id
        }
    }

    func details(for entry: BanEntry) -> String {
        var parts = [String]()
        if !entry.username.isEmpty {
            parts.append(String(format: String(localized: "User name: %@", comment: "ban list"), entry.username))
        }
        if !entry.ipAddress.isEmpty {
            parts.append(String(format: String(localized: "IP address: %@", comment: "ban list"), entry.ipAddress))
        }
        if !entry.channelPath.isEmpty {
            parts.append(String(format: String(localized: "Channel: %@", comment: "ban list"), entry.channelPath))
        }
        if !entry.banTime.isEmpty {
            parts.append(String(format: String(localized: "Banned on %@", comment: "ban list"), entry.banTime))
        }
        if !entry.owner.isEmpty {
            parts.append(String(format: String(localized: "Banned by %@", comment: "ban list"), entry.owner))
        }
        return parts.joined(separator: "\n")
    }

    func handleTTMessage(_ m: TTMessage) {
        switch m.nClientEvent {
        case CLIENTEVENT_CMD_BANNEDUSER:
            if isLoading {
                entries.append(BanEntry(TeamTalkMessagePayload.bannedUser(from: m)))
            }
        case CLIENTEVENT_CMD_PROCESSING:
            if !TeamTalkMessagePayload.isActive(m) && m.nSource == listCommand {
                isLoading = false
                listCommand = 0
            }
        case CLIENTEVENT_CMD_SUCCESS:
            if let id = unbanCommands.removeValue(forKey: m.nSource) {
                entries.removeAll { $0.id == id }
                announceForAccessibility(String(localized: "Ban removed", comment: "ban list"))
            }
        case CLIENTEVENT_CMD_ERROR:
            if m.nSource == listCommand || unbanCommands.removeValue(forKey: m.nSource) != nil {
                errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            }
        default:
            break
        }
    }
}

struct BanListView: View {
    @StateObject private var model = BanListModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.isLoading {
                    ProgressView()
                } else if model.entries.isEmpty {
                    Text("No banned users")
                        .foregroundStyle(.secondary)
                }

                ForEach(model.entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                        Text(model.details(for: entry))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .swipeActions(edge: .trailing) {
                        Button {
                            model.unban(entry)
                        } label: {
                            Label("Remove Ban", systemImage: "checkmark.circle")
                        }
                        .tint(.green)
                    }
                }
            }
            .navigationTitle("Banned Users")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
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
            .onAppear {
                addToTTMessages(model)
                model.load()
            }
        }
    }
}
