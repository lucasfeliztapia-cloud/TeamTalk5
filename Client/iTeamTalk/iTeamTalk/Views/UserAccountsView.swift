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

    /// What a new account may do: the same as on the Windows client
    /// (USERRIGHT_DEFAULT in utiltt.h). The library has no constant for it.
    static let defaults: UInt32 = [
        USERRIGHT_MULTI_LOGIN, USERRIGHT_VIEW_ALL_USERS, USERRIGHT_CREATE_TEMPORARY_CHANNEL,
        USERRIGHT_UPLOAD_FILES, USERRIGHT_DOWNLOAD_FILES, USERRIGHT_TRANSMIT_VOICE,
        USERRIGHT_TRANSMIT_VIDEOCAPTURE, USERRIGHT_TRANSMIT_DESKTOP, USERRIGHT_TRANSMIT_DESKTOPINPUT,
        USERRIGHT_TRANSMIT_MEDIAFILE_AUDIO, USERRIGHT_TRANSMIT_MEDIAFILE_VIDEO,
        USERRIGHT_TEXTMESSAGE_USER, USERRIGHT_TEXTMESSAGE_CHANNEL
    ].reduce(UInt32(0)) { $0 | $1.rawValue }

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

    /// An account of no type: it is kept, but nobody can log in with it
    var isDisabled: Bool {
        (account.uUserType & (USERTYPE_ADMIN.rawValue | USERTYPE_DEFAULT.rawValue)) == 0
    }

    var typeTitle: String {
        if isAdministrator {
            return String(localized: "Administrator", comment: "user accounts")
        }
        if isDisabled {
            return String(localized: "Disabled Account", comment: "user accounts")
        }
        return String(localized: "Default user", comment: "user accounts")
    }

    /// The account without a user name is the one anybody logs in with
    var title: String {
        username.isEmpty ? String(localized: "Anonymous users", comment: "user accounts") : username
    }

    var subtitle: String {
        var parts = [typeTitle]
        let note = TeamTalkString.userAccount(.note, from: account)
        if !note.isEmpty {
            parts.append(note)
        }
        return parts.joined(separator: ". ")
    }
}

/// The user accounts of the server. Only an administrator can list, create,
/// change and delete them. An account is saved whole, as it came from the
/// server, with nothing changed but what the user touched. The server applies
/// an account when the user logs in, so a change does not reach who is
/// already connected.
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
    // an account being created or changed in the editor, which closes when
    // the count goes up
    @Published var isSaving = false
    @Published var savedCount = 0

    private var listCommand: INT32 = 0
    private var saveCommands = [INT32: UserAccount]()

    // accounts are changed one after the other, each once the server has answered
    private var bulkQueue = [UserAccount]()
    private var bulkCommand: INT32 = 0
    private var bulkFailures = 0

    private var editCommand: INT32 = 0
    private var renamedFrom: String?
    private var deleteCommands = [INT32: String]()
    // the old name of a renamed account goes without a word
    private var quietDeletes = Set<INT32>()

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

    // MARK: Creating, changing and deleting

    /// Creates the account, or replaces the one of the same user name. For a
    /// renamed account the one of the old name is deleted once the new one is
    /// in place, never before: a failure must not leave the user with neither.
    func save(_ account: UserAccount, renamedFrom old: String?) {
        let cmdid = TeamTalkClient.shared.saveUserAccount(account)
        guard cmdid > 0 else {
            errorMessage = String(localized: "The account could not be saved", comment: "user accounts")
            return
        }
        saveCommands[cmdid] = account
        editCommand = cmdid
        renamedFrom = old
        isSaving = true
    }

    func delete(username: String) {
        sendDelete(username, quietly: false)
    }

    private func sendDelete(_ username: String, quietly: Bool) {
        let cmdid = TeamTalkClient.shared.deleteUserAccount(username: username)
        guard cmdid > 0 else {
            errorMessage = String(localized: "The account could not be deleted", comment: "user accounts")
            return
        }
        deleteCommands[cmdid] = username
        if quietly {
            quietDeletes.insert(cmdid)
        }
    }

    private func accountSaved(_ account: UserAccount) {
        editCommand = 0
        isSaving = false
        let username = TeamTalkString.userAccount(.username, from: account)
        if let old = renamedFrom, old != username {
            sendDelete(old, quietly: true)
        }
        renamedFrom = nil
        sortEntries()
        savedCount += 1
        announceForAccessibility(String(localized: "Account saved", comment: "user accounts"))
    }

    private func sortEntries() {
        entries.sort {
            $0.title.caseInsensitiveCompare($1.title) == .orderedAscending
        }
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
                if m.nSource == editCommand {
                    accountSaved(account)
                }
            } else if let username = deleteCommands.removeValue(forKey: m.nSource) {
                entries.removeAll { $0.username == username }
                if quietDeletes.remove(m.nSource) == nil {
                    announceForAccessibility(String(localized: "Account deleted", comment: "user accounts"))
                }
            }

        case CLIENTEVENT_CMD_ERROR:
            if m.nSource == listCommand {
                errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            } else if saveCommands.removeValue(forKey: m.nSource) != nil {
                if m.nSource == bulkCommand {
                    bulkFailures += 1
                } else {
                    if m.nSource == editCommand {
                        editCommand = 0
                        isSaving = false
                        renamedFrom = nil
                    }
                    errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
                    // what is shown is no longer what the server has
                    load()
                }
            } else if deleteCommands.removeValue(forKey: m.nSource) != nil {
                quietDeletes.remove(m.nSource)
                errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
                load()
            }

        case CLIENTEVENT_CMD_PROCESSING:
            guard !TeamTalkMessagePayload.isActive(m) else { break }
            if m.nSource == listCommand {
                isLoading = false
                listCommand = 0
                sortEntries()
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

private enum AccountsTab: Hashable {
    case permissions
    case management
}

struct UserAccountsView: View {
    /// The channels of the server, to choose the initial channel of an account
    let channels: [ChannelNode]
    /// The account in use: deleting it deserves a word
    let ownUsername: String

    @StateObject private var model = UserAccountsModel()
    @Environment(\.dismiss) private var dismiss
    @State private var tab = AccountsTab.permissions
    @State private var pendingDeletion: AccountEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // what each account may do on one side, the accounts
                // themselves on the other
                Picker("User Accounts", selection: $tab) {
                    Text("Permissions").tag(AccountsTab.permissions)
                    Text("Manage").tag(AccountsTab.management)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                List {
                    if model.isLoading {
                        ProgressView()
                    } else if tab == .permissions {
                        permissionRows
                    } else {
                        managementRows
                    }
                }
            }
            .navigationTitle("User Accounts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $model.searchText, prompt: "Search accounts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                addToTTMessages(model)
                if model.entries.isEmpty {
                    model.load()
                }
            }
        }
        // on the stack itself, so that they come up over the editor too
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Delete Account", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { entry in
            Button("Delete", role: .destructive) {
                model.delete(username: entry.username)
            }
            Button("Cancel", role: .cancel) { }
        } message: { entry in
            Text(verbatim: accountDeletionMessage(entry, ownUsername: ownUsername))
        }
    }

    @ViewBuilder
    private var permissionRows: some View {
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
                    accountLabel(entry)
                }
            }
        } header: {
            Text(verbatim: countTitle)
        }
    }

    @ViewBuilder
    private var managementRows: some View {
        Section {
            NavigationLink {
                AccountEditorView(model: model, original: nil, channels: channels, ownUsername: ownUsername)
            } label: {
                Label("New Account", systemImage: "person.badge.plus")
            }
        } footer: {
            Text("Choose an account to change it or to delete it.")
        }

        Section {
            if model.visibleEntries.isEmpty {
                Text("No user accounts")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.visibleEntries) { entry in
                NavigationLink {
                    AccountEditorView(model: model, original: entry, channels: channels, ownUsername: ownUsername)
                } label: {
                    accountLabel(entry)
                }
                // one set of them: VoiceOver lists Delete once among the
                // actions of the row
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        pendingDeletion = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        } header: {
            Text(verbatim: countTitle)
        }
    }

    private func accountLabel(_ entry: AccountEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
            Text(entry.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var countTitle: String {
        String(format: String(localized: "%d accounts", comment: "user accounts"), model.entries.count)
    }
}

/// What is asked before deleting an account
private func accountDeletionMessage(_ entry: AccountEntry, ownUsername: String) -> String {
    var message = String(format: String(localized: "The account %@ will be deleted. Whoever is connected with it stays connected until they leave.", comment: "user accounts"), entry.title)
    if entry.username == ownUsername {
        message += " " + String(localized: "This is the account you are logged in with.", comment: "user accounts")
    }
    return message
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

// MARK: - Creating and changing an account

private enum AccountType: Hashable {
    case standard
    case administrator
    case disabled

    init(_ userType: UInt32) {
        if (userType & USERTYPE_ADMIN.rawValue) != 0 {
            self = .administrator
        } else if (userType & USERTYPE_DEFAULT.rawValue) != 0 {
            self = .standard
        } else {
            self = .disabled
        }
    }

    var userType: UInt32 {
        switch self {
        case .standard:
            return USERTYPE_DEFAULT.rawValue
        case .administrator:
            return USERTYPE_ADMIN.rawValue
        case .disabled:
            return USERTYPE_NONE.rawValue
        }
    }
}

/// How many commands an account may send to the server in a given time. The
/// same choices as the Windows client, plus whatever the account came with.
private struct CommandLimit: Hashable {
    let commands: INT32
    let milliseconds: INT32

    static let unlimited = CommandLimit(commands: 0, milliseconds: 0)

    static let presets = [
        CommandLimit(commands: 10, milliseconds: 10_000),
        CommandLimit(commands: 10, milliseconds: 60_000),
        CommandLimit(commands: 60, milliseconds: 60_000)
    ]

    init(commands: INT32, milliseconds: INT32) {
        self.commands = commands
        self.milliseconds = milliseconds
    }

    /// The server takes either of them at zero as no limit
    init(_ abuse: AbusePrevention) {
        if abuse.nCommandsLimit > 0 && abuse.nCommandsIntervalMSec > 0 {
            commands = abuse.nCommandsLimit
            milliseconds = abuse.nCommandsIntervalMSec
        } else {
            commands = 0
            milliseconds = 0
        }
    }

    var title: String {
        if commands == 0 {
            return String(localized: "No Limit", comment: "user accounts")
        }
        return String(format: String(localized: "Commands: %d. Seconds: %d.", comment: "user accounts"),
                      Int(commands), Int(milliseconds / 1000))
    }
}

/// Creates an account or changes one. What the form does not show, like the
/// permissions and the channels where the user is operator, is sent as it
/// came from the server.
private struct AccountEditorView: View {
    @ObservedObject var model: UserAccountsModel
    /// nil to create an account
    let original: AccountEntry?
    let channels: [ChannelNode]
    let ownUsername: String

    @Environment(\.dismiss) private var dismiss
    @State private var didLoad = false
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var accountType = AccountType.standard
    @State private var note = ""
    @State private var initialChannel = ""
    @State private var commandLimit = CommandLimit.unlimited
    @State private var choosingChannel = false
    @State private var confirmingAnonymous = false
    @State private var confirmingDeletion = false
    @State private var validationMessage: String?

    private var isOwnAccount: Bool {
        guard let original else { return false }
        return original.username == ownUsername
    }

    private var typeExplanation: LocalizedStringKey {
        switch accountType {
        case .standard:
            return "Has the permissions given to the account in the Permissions tab"
        case .administrator:
            return "Has every permission and manages the server"
        case .disabled:
            return "Nobody can log in with this account until its type is changed"
        }
    }

    private var limitOptions: [CommandLimit] {
        var options = [CommandLimit.unlimited] + CommandLimit.presets
        if let original {
            let own = CommandLimit(original.account.abusePrevent)
            if !options.contains(own) {
                options.append(own)
            }
        }
        return options
    }

    private var initialChannelTitle: String {
        initialChannel.isEmpty ? String(localized: "No channel", comment: "user accounts") : initialChannel
    }

    private var title: String {
        guard let original else {
            return String(localized: "New Account", comment: "user accounts")
        }
        return original.title
    }

    var body: some View {
        Form {
            noticeSection
            identitySection
            typeSection
            channelSection
            limitSection
            if let original {
                historySection(original)
                Section {
                    Button("Delete Account", role: .destructive) {
                        confirmingDeletion = true
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(model.isSaving)
            }
        }
        .onAppear(perform: loadOnce)
        // the server has taken the account
        .onChange(of: model.savedCount) { _ in
            dismiss()
        }
        .sheet(isPresented: $choosingChannel) {
            ChannelPickerView(channels: channels, confirmTitle: "OK") { channelID in
                initialChannel = TeamTalkClient.shared.channelPath(id: channelID)
            }
        }
        .alert("User Accounts", isPresented: Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage ?? "")
        }
        .alert("Anonymous Account", isPresented: $confirmingAnonymous) {
            Button("Save", action: send)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("An account with no user name is the one anybody can log in with.")
        }
        .alert("Delete Account", isPresented: $confirmingDeletion) {
            Button("Delete", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(verbatim: deletionMessage)
        }
    }

    private var deletionMessage: String {
        guard let original else { return "" }
        return accountDeletionMessage(original, ownUsername: ownUsername)
    }

    @ViewBuilder
    private var noticeSection: some View {
        if original == nil {
            Section {
                Text("A new account gets the default permissions. They are changed in the Permissions tab.")
                    .foregroundStyle(.secondary)
            }
        } else if isOwnAccount {
            Section {
                Text("This is the account you are logged in with.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var identitySection: some View {
        Section {
            LabeledContent {
                TextField("", text: $username)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel(Text("Username"))
            } label: {
                Text("Username")
                    .accessibilityHidden(true)
            }
            passwordField
            Toggle("Show password", isOn: $showPassword)
            LabeledContent {
                TextField("", text: $note)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text("Note"))
            } label: {
                Text("Note")
                    .accessibilityHidden(true)
            }
        } header: {
            Text("Account")
        } footer: {
            Text("An account with no user name is the one anybody can log in with.")
        }
    }

    private var passwordField: some View {
        LabeledContent {
            Group {
                if showPassword {
                    TextField("", text: $password)
                        .autocorrectionDisabled()
                } else {
                    SecureField("", text: $password)
                }
            }
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .accessibilityLabel(Text("Password"))
        } label: {
            Text("Password")
                .accessibilityHidden(true)
        }
    }

    private var typeSection: some View {
        Section {
            Picker("Account Type", selection: $accountType) {
                Text("Default user").tag(AccountType.standard)
                Text("Administrator").tag(AccountType.administrator)
                Text("Disabled Account").tag(AccountType.disabled)
            }
        } footer: {
            Text(typeExplanation)
        }
    }

    private var channelSection: some View {
        Section {
            LabeledContent("Initial Channel", value: initialChannelTitle)
            Button("Choose Channel") {
                choosingChannel = true
            }
            if !initialChannel.isEmpty {
                Button("Remove Initial Channel") {
                    initialChannel = ""
                }
            }
        } footer: {
            Text("The channel the user joins after logging in. Its password is not asked for.")
        }
    }

    private var limitSection: some View {
        Section {
            Picker("Command Limit", selection: $commandLimit) {
                ForEach(limitOptions, id: \.self) { limit in
                    Text(verbatim: limit.title).tag(limit)
                }
            }
        } footer: {
            Text("How many commands the user can send to the server in a given time. It stops floods of messages.")
        }
    }

    /// When the account was last used and last changed, as the server says it
    @ViewBuilder
    private func historySection(_ entry: AccountEntry) -> some View {
        let lastLogin = TeamTalkString.userAccount(.lastLogin, from: entry.account)
        let lastChange = TeamTalkString.userAccount(.lastModified, from: entry.account)
        if !lastLogin.isEmpty || !lastChange.isEmpty {
            Section {
                if !lastLogin.isEmpty {
                    LabeledContent("Last Login", value: lastLogin)
                }
                if !lastChange.isEmpty {
                    LabeledContent("Last Change", value: lastChange)
                }
            }
        }
    }

    private func loadOnce() {
        guard !didLoad else { return }
        didLoad = true
        guard let original else { return }
        username = original.username
        password = TeamTalkString.userAccount(.password, from: original.account)
        note = TeamTalkString.userAccount(.note, from: original.account)
        initialChannel = TeamTalkString.userAccount(.initialChannel, from: original.account)
        accountType = AccountType(original.account.uUserType)
        commandLimit = CommandLimit(original.account.abusePrevent)
    }

    private var writtenUsername: String {
        username.trimmingCharacters(in: .whitespaces)
    }

    /// The account takes a user name that it did not have
    private var takesNewName: Bool {
        guard let original else { return true }
        return original.username != writtenUsername
    }

    private func save() {
        // saving over another account would replace it without a word
        if takesNewName && model.entry(writtenUsername) != nil {
            validationMessage = String(localized: "The server already has an account with that user name", comment: "user accounts")
            return
        }
        if takesNewName && writtenUsername.isEmpty {
            confirmingAnonymous = true
            return
        }
        send()
    }

    private func send() {
        var account = original?.account ?? UserAccount()
        let name = writtenUsername
        TeamTalkString.setUserAccount(.username, on: &account, to: name)
        TeamTalkString.setUserAccount(.password, on: &account, to: password)
        TeamTalkString.setUserAccount(.note, on: &account, to: note)
        TeamTalkString.setUserAccount(.initialChannel, on: &account, to: initialChannel)
        account.uUserType = accountType.userType
        // A new account starts with the default permissions, like on Windows.
        // So does one that becomes a default user having none at all, as an
        // administrator may: it could do nothing.
        if original == nil || (accountType == .standard && account.uUserRights == 0) {
            account.uUserRights = AccountRights.defaults
        }
        account.abusePrevent.nCommandsLimit = commandLimit.commands
        account.abusePrevent.nCommandsIntervalMSec = commandLimit.milliseconds

        var renamedFrom: String?
        if let original, original.username != name {
            renamedFrom = original.username
        }
        model.save(account, renamedFrom: renamedFrom)
    }

    private func deleteAccount() {
        if let original {
            model.delete(username: original.username)
        }
        dismiss()
    }
}
