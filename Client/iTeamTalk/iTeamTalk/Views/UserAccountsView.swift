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

// MARK: - The rights of a user account

struct AccountRight: Identifiable {
    let flag: UInt32
    let title: String

    var id: UInt32 {
        flag
    }
}

struct AccountRightGroup: Identifiable {
    let title: String
    let rights: [AccountRight]

    var id: String {
        title
    }
}

enum AccountRights {

    static let groups: [AccountRightGroup] = [
        AccountRightGroup(title: String(localized: "Transmission", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_TRANSMIT_VOICE.rawValue,
                         title: String(localized: "Transmit voice", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TRANSMIT_VIDEOCAPTURE.rawValue,
                         title: String(localized: "Transmit video", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TRANSMIT_DESKTOP.rawValue,
                         title: String(localized: "Share the desktop", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TRANSMIT_DESKTOPINPUT.rawValue,
                         title: String(localized: "Control a shared desktop", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TRANSMIT_MEDIAFILE_AUDIO.rawValue,
                         title: String(localized: "Stream audio files", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TRANSMIT_MEDIAFILE_VIDEO.rawValue,
                         title: String(localized: "Stream video files", comment: "user accounts"))
        ]),
        AccountRightGroup(title: String(localized: "Text Messages", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_TEXTMESSAGE_USER.rawValue,
                         title: String(localized: "Send private messages", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TEXTMESSAGE_CHANNEL.rawValue,
                         title: String(localized: "Send channel messages", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_TEXTMESSAGE_BROADCAST.rawValue,
                         title: String(localized: "Send broadcast messages", comment: "user accounts"))
        ]),
        AccountRightGroup(title: String(localized: "Channels", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_VIEW_ALL_USERS.rawValue,
                         title: String(localized: "See the users of every channel", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_VIEW_HIDDEN_CHANNELS.rawValue,
                         title: String(localized: "See hidden channels", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_CREATE_TEMPORARY_CHANNEL.rawValue,
                         title: String(localized: "Create temporary channels", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_MODIFY_CHANNELS.rawValue,
                         title: String(localized: "Create and change permanent channels", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_OPERATOR_ENABLE.rawValue,
                         title: String(localized: "Make other users channel operator", comment: "user accounts"))
        ]),
        AccountRightGroup(title: String(localized: "Files", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_UPLOAD_FILES.rawValue,
                         title: String(localized: "Upload files", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_DOWNLOAD_FILES.rawValue,
                         title: String(localized: "Download files", comment: "user accounts"))
        ]),
        AccountRightGroup(title: String(localized: "Moderation", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_KICK_USERS.rawValue,
                         title: String(localized: "Kick users off the server", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_BAN_USERS.rawValue,
                         title: String(localized: "Ban users", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_MOVE_USERS.rawValue,
                         title: String(localized: "Move users between channels", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_UPDATE_SERVERPROPERTIES.rawValue,
                         title: String(localized: "Change the properties of the server", comment: "user accounts"))
        ]),
        AccountRightGroup(title: String(localized: "Other", comment: "user accounts"), rights: [
            AccountRight(flag: USERRIGHT_MULTI_LOGIN.rawValue,
                         title: String(localized: "Log in from several devices at once", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_RECORD_VOICE.rawValue,
                         title: String(localized: "Record voice in every channel", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_LOCKED_NICKNAME.rawValue,
                         title: String(localized: "Nickname locked, cannot be changed", comment: "user accounts")),
            AccountRight(flag: USERRIGHT_LOCKED_STATUS.rawValue,
                         title: String(localized: "Status locked, cannot be changed", comment: "user accounts"))
        ])
    ]
}

// MARK: - Model

struct AccountEntry: Identifiable {
    var account: UserAccount
    let username: String

    init(_ account: UserAccount) {
        self.account = account
        username = TeamTalkString.userAccount(.username, from: account)
    }

    var id: String {
        username
    }

    var isAdministrator: Bool {
        (account.uUserType & USERTYPE_ADMIN.rawValue) != 0
    }

    /// The account without a user name is the one anybody logs in with
    var title: String {
        username.isEmpty ? String(localized: "Anonymous users", comment: "user accounts") : username
    }

    var subtitle: String {
        var parts = [isAdministrator
            ? String(localized: "Administrator", comment: "user accounts")
            : String(localized: "Default user", comment: "user accounts")]
        let note = TeamTalkString.userAccount(.note, from: account)
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: ". ")
    }
}

/// The user accounts of the server and their rights. Only an administrator
/// can list and change them. An account is saved whole, as it came from the
/// server, with nothing but its rights changed. The server applies the rights
/// when the user logs in, so a change does not reach who is already connected.
final class UserAccountsModel: ObservableObject, TeamTalkEvent {

    struct BulkProgress {
        var done: Int
        let total: Int
    }

    @Published var entries = [AccountEntry]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var bulkProgress: BulkProgress?
    @Published var bulkResult: String?

    private var listCommand: INT32 = 0
    private var saveCommands = [INT32: UserAccount]()

    // accounts are changed one after the other, each once the server has answered
    private var bulkQueue = [UserAccount]()
    private var bulkCommand: INT32 = 0
    private var bulkFailures = 0

    var visibleEntries: [AccountEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    /// The accounts a change of all accounts applies to
    var changeableCount: Int {
        entries.filter { !$0.isAdministrator }.count
    }

    func load() {
        entries = []
        listCommand = TeamTalkClient.shared.listUserAccounts()
        isLoading = listCommand > 0
    }

    func entry(_ username: String) -> AccountEntry? {
        entries.first { $0.username == username }
    }

    func hasRight(_ flag: UInt32, username: String) -> Bool {
        guard let entry = entry(username) else { return false }
        return (entry.account.uUserRights & flag) != 0
    }

    func setRight(_ flag: UInt32, enabled: Bool, username: String) {
        guard let index = entries.firstIndex(where: { $0.username == username }) else { return }

        var account = entries[index].account
        account.uUserRights = enabled ? account.uUserRights | flag : account.uUserRights & ~flag
        guard account.uUserRights != entries[index].account.uUserRights else { return }

        let cmdid = TeamTalkClient.shared.saveUserAccount(account)
        guard cmdid > 0 else {
            errorMessage = String(localized: "The account could not be saved", comment: "user accounts")
            return
        }
        saveCommands[cmdid] = account
        // shown at once, the next change starts from it. An error reloads the list.
        entries[index].account = account
        logDiagnostic("Account rights: \(enabled ? "gave" : "removed") 0x\(String(flag, radix: 16)) on one account")
    }

    // MARK: Every account at once

    func changeAllAccounts(rights: UInt32, grant: Bool) {
        guard bulkProgress == nil, rights != 0 else { return }

        bulkQueue = entries.filter { !$0.isAdministrator }.compactMap { entry in
            var account = entry.account
            account.uUserRights = grant ? account.uUserRights | rights : account.uUserRights & ~rights
            // already as asked: nothing to send
            return account.uUserRights == entry.account.uUserRights ? nil : account
        }
        bulkFailures = 0

        guard !bulkQueue.isEmpty else {
            bulkResult = String(localized: "Every account was already like that. Nothing has been changed.", comment: "user accounts")
            return
        }
        logDiagnostic("Account rights: \(grant ? "giving" : "removing") 0x\(String(rights, radix: 16)) on \(bulkQueue.count) accounts")
        bulkProgress = BulkProgress(done: 0, total: bulkQueue.count)
        sendNextOfBulk()
    }

    private func sendNextOfBulk() {
        guard let progress = bulkProgress else { return }

        while !bulkQueue.isEmpty {
            let account = bulkQueue.removeFirst()
            bulkCommand = TeamTalkClient.shared.saveUserAccount(account)
            if bulkCommand > 0 {
                saveCommands[bulkCommand] = account
                return
            }
            bulkFailures += 1
            bulkProgress?.done += 1
        }

        // all sent and answered
        bulkCommand = 0
        bulkProgress = nil
        let changed = progress.total - bulkFailures
        logDiagnostic("Account rights: \(changed) accounts changed, \(bulkFailures) failed")
        bulkResult = bulkFailures == 0
            ? String(format: String(localized: "%d accounts changed. It applies to each user the next time they log in.", comment: "user accounts"), changed)
            : String(format: String(localized: "%d accounts changed and %d could not be changed.", comment: "user accounts"), changed, bulkFailures)
        if bulkFailures > 0 {
            load()
        }
    }

    private func store(_ account: UserAccount) {
        let entry = AccountEntry(account)
        if let index = entries.firstIndex(where: { $0.username == entry.username }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    func handleTTMessage(_ m: TTMessage) {
        switch m.nClientEvent {
        case CLIENTEVENT_CMD_USERACCOUNT:
            if isLoading {
                entries.append(AccountEntry(TeamTalkMessagePayload.userAccount(from: m)))
            }

        case CLIENTEVENT_CMD_USERACCOUNT_NEW:
            // the account as the server has it now
            if !isLoading {
                store(TeamTalkMessagePayload.userAccount(from: m))
            }

        case CLIENTEVENT_CMD_USERACCOUNT_REMOVE:
            let username = TeamTalkString.userAccount(.username, from: TeamTalkMessagePayload.userAccount(from: m))
            // a replaced account is removed and added again: only drop what stays gone
            if !saveCommands.values.contains(where: { TeamTalkString.userAccount(.username, from: $0) == username }) {
                entries.removeAll { $0.username == username }
            }

        case CLIENTEVENT_CMD_SUCCESS:
            if let account = saveCommands.removeValue(forKey: m.nSource) {
                store(account)
            }

        case CLIENTEVENT_CMD_ERROR:
            if m.nSource == listCommand {
                errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            } else if saveCommands.removeValue(forKey: m.nSource) != nil {
                if m.nSource == bulkCommand {
                    bulkFailures += 1
                } else {
                    errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
                    // what is shown is no longer what the server has
                    load()
                }
            }

        case CLIENTEVENT_CMD_PROCESSING:
            guard !TeamTalkMessagePayload.isActive(m) else { break }
            if m.nSource == listCommand {
                isLoading = false
                listCommand = 0
                entries.sort {
                    $0.title.caseInsensitiveCompare($1.title) == .orderedAscending
                }
            } else if m.nSource == bulkCommand, bulkProgress != nil {
                bulkProgress?.done += 1
                sendNextOfBulk()
            }

        default:
            break
        }
    }
}

// MARK: - Views

struct UserAccountsView: View {
    @StateObject private var model = UserAccountsModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if model.isLoading {
                    ProgressView()
                } else {
                    Section {
                        NavigationLink {
                            AllAccountsRightsView(model: model)
                        } label: {
                            Label("Change the Permissions of Every Account", systemImage: "person.3.sequence")
                        }
                    } footer: {
                        Text("A change of permissions applies the next time the user logs in. Whoever is connected keeps the old ones until then.")
                    }

                    Section {
                        if model.visibleEntries.isEmpty {
                            Text("No user accounts")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(model.visibleEntries) { entry in
                            NavigationLink {
                                AccountRightsView(model: model, username: entry.username)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                    Text(entry.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(verbatim: String(format: String(localized: "%d accounts", comment: "user accounts"), model.entries.count))
                    }
                }
            }
            .navigationTitle("User Accounts")
            .searchable(text: $model.searchText, prompt: "Search accounts")
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
                if model.entries.isEmpty {
                    model.load()
                }
            }
        }
    }
}

/// The permissions of one account, each with its switch
private struct AccountRightsView: View {
    @ObservedObject var model: UserAccountsModel
    let username: String

    var body: some View {
        let entry = model.entry(username)
        let isAdministrator = entry?.isAdministrator ?? false

        List {
            if isAdministrator {
                Section {
                    Text("An administrator has every permission, whatever is set here.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(AccountRights.groups) { group in
                Section(group.title) {
                    ForEach(group.rights) { right in
                        Toggle(right.title, isOn: Binding(
                            get: { model.hasRight(right.flag, username: username) },
                            set: { model.setRight(right.flag, enabled: $0, username: username) }
                        ))
                    }
                }
            }
            .disabled(isAdministrator)

            Section {
            } footer: {
                Text("Each change is saved at once and applies the next time this user logs in.")
            }
        }
        .navigationTitle(entry?.title ?? username)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Gives or removes several permissions on every account at once
private struct AllAccountsRightsView: View {
    @ObservedObject var model: UserAccountsModel
    @State private var selected = Set<UInt32>()
    @State private var pendingGrant: Bool?

    private var selectedMask: UInt32 {
        selected.reduce(0) { $0 | $1 }
    }

    var body: some View {
        List {
            Section {
                Text("Choose one or more permissions and then what to do with them. Administrator accounts are not changed.")
                    .foregroundStyle(.secondary)
            }

            ForEach(AccountRights.groups) { group in
                Section(group.title) {
                    ForEach(group.rights) { right in
                        Toggle(right.title, isOn: Binding(
                            get: { selected.contains(right.flag) },
                            set: { isOn in
                                if isOn {
                                    selected.insert(right.flag)
                                } else {
                                    selected.remove(right.flag)
                                }
                            }
                        ))
                    }
                }
            }

            Section {
                if let progress = model.bulkProgress {
                    ProgressView(value: Double(progress.done), total: Double(progress.total)) {
                        Text(verbatim: String(format: String(localized: "Changing accounts, %d of %d", comment: "user accounts"),
                                              progress.done, progress.total))
                    }
                } else {
                    Button(role: .destructive) {
                        pendingGrant = false
                    } label: {
                        Text("Remove from Every Account")
                    }
                    Button {
                        pendingGrant = true
                    } label: {
                        Text("Give to Every Account")
                    }
                }
            } header: {
                Text(verbatim: String(format: String(localized: "%d permissions chosen", comment: "user accounts"), selected.count))
            } footer: {
                Text("It applies to each user the next time they log in.")
            }
            .disabled(selected.isEmpty)
        }
        .navigationTitle("Every Account")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            Text("Confirm"),
            isPresented: Binding(
                get: { pendingGrant != nil },
                set: { if !$0 { pendingGrant = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingGrant
        ) { grant in
            if grant {
                Button("Give to Every Account") {
                    model.changeAllAccounts(rights: selectedMask, grant: true)
                }
            } else {
                Button("Remove from Every Account", role: .destructive) {
                    model.changeAllAccounts(rights: selectedMask, grant: false)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { grant in
            Text(verbatim: String(
                format: grant
                    ? String(localized: "%d permissions will be given to the %d accounts of the server that are not administrators.", comment: "user accounts")
                    : String(localized: "%d permissions will be removed from the %d accounts of the server that are not administrators.", comment: "user accounts"),
                selected.count, model.changeableCount))
        }
        .alert("User Accounts", isPresented: Binding(
            get: { model.bulkResult != nil },
            set: { if !$0 { model.bulkResult = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.bulkResult ?? "")
        }
    }
}
