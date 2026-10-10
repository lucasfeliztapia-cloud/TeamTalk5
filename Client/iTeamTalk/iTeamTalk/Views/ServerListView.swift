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

struct ServerListView: View {
    @ObservedObject var model: ServerListModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        Group {
            if let mainTabModel = model.activeMainTabModel {
                MainTabView(model: mainTabModel, close: {
                    model.closeActiveServer()
                })
            } else {
                serverList
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .iTeamTalkOpenURL)) { notification in
            guard let url = notification.object as? URL else { return }
            model.openUrl(url)
        }
    }

    private var serverList: some View {
        NavigationStack(path: $model.navigationPath) {
            List {
                Button {
                    model.showJoinCodeAlert = true
                } label: {
                    Text("Enter Join Code")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                searchField

                ForEach(model.visibleServers, id: \.self) { server in
                    serverRow(server)
                    .onTapGesture {
                        model.showServerDetail(for: server)
                    }
                    // VoiceOver gets every action once and by name, in
                    // serverRow. With the swipe actions left in while it runs,
                    // each of them showed up twice in the rotor.
                    .swipeActions(edge: .trailing) {
                        if !voiceOverEnabled {
                            Button {
                                model.serverPendingDeletion = server
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !voiceOverEnabled {
                            serverActions(server)
                        }
                    }
                    .contextMenu {
                        serverActions(server)
                    }
                }
            }
            .navigationTitle("TeamTalk Servers")
            .sheet(item: $model.sharedFile) { shared in
                ActivityView(items: [shared.url])
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        model.openPreferences()
                    } label: {
                        Image("setup")
                            .accessibilityLabel("Preferences")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        model.addServer()
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add new server entry")
                    }
                }
            }
            .navigationDestination(for: ServerListDestination.self) { destination in
                destinationView(destination)
            }
            .alert("Connect to Server",
                isPresented: $model.showJoinCodeAlert
            ) {
                TextField("Type Join Code",
                    text: $model.joinCodeInput
                )
                .autocorrectionDisabled()
                Button("OK") {
                    model.submitJoinCode()
                }
                Button("Cancel", role: .cancel) {
                    model.joinCodeInput = ""
                }
            } message: {
                Text("Enter Join Code")
            }
            .alert("Connect to Server",
                isPresented: Binding(
                    get: { model.errorMessage != nil },
                    set: { if !$0 { model.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .alert("Send to TeamTalk",
                isPresented: Binding(
                    get: { model.infoMessage != nil },
                    set: { if !$0 { model.infoMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.infoMessage ?? "")
            }
            .alert("Delete Server",
                isPresented: Binding(
                    get: { model.serverPendingDeletion != nil },
                    set: { if !$0 { model.serverPendingDeletion = nil } }
                ),
                presenting: model.serverPendingDeletion
            ) { server in
                Button("Delete", role: .destructive) {
                    model.deleteServer(server)
                }
                Button("Cancel", role: .cancel) {}
            } message: { server in
                Text("Delete \"\(server.name)\" from the server list?")
            }
            .onAppear {
                model.onAppear()
            }
            .sheet(item: $model.serverDetailModel) { detailModel in
                ServerDetailSheetView(detailModel: detailModel, listModel: model)
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: ServerListDestination) -> some View {
        switch destination {
        case .preferences(let m):
            PreferencesView(model: m)
        }
    }

    /// The search field as a row of the list, right below "Enter Join Code".
    /// The one of the system sits under the list since iOS 26, after every
    /// server.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search servers", text: $model.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !model.searchText.isEmpty {
                Button {
                    model.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Clear text"))
            }
        }
    }

    /// One server of the list. On its own so the compiler checks it apart
    /// from the list: all in one expression it ran out of time.
    private func serverRow(_ server: Server) -> some View {
        HStack(spacing: 10) {
            Image(iconName(for: server))
                .resizable()
                .frame(width: 36, height: 36)
                .accessibilityLabel(iconAccessibilityLabel(for: server))

            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.body)
                    .lineLimit(1)
                Text(detail(for: server))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if model.isFavorite(server) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Favorite")
            }

            Spacer(minLength: 12)

            Button("Connect") {
                model.connect(to: server)
            }
            .buttonStyle(.bordered)
            // activating the row connects; as a child it was one more action
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Connects to this server"))
        .accessibilityAction {
            model.connect(to: server)
        }
        .accessibilityAction(named: Text("Show server details")) {
            model.showServerDetail(for: server)
        }
        .accessibilityAction(named: Text(model.isFavorite(server)
            ? LocalizedStringKey("Remove from Favorites")
            : LocalizedStringKey("Add to Favorites"))) {
            model.toggleFavorite(server)
        }
        .accessibilityAction(named: Text("Share Server")) {
            model.shareServer(server)
        }
        .accessibilityAction(named: Text("Copy Link")) {
            model.copyLink(of: server)
        }
        .accessibilityAction(named: Text("Delete")) {
            model.serverPendingDeletion = server
        }
        .contentShape(Rectangle())
    }

    /// Favorite, share and copy link: offered as swipe actions, which VoiceOver
    /// lists as actions of the row, and as a menu when the row is held.
    @ViewBuilder
    private func serverActions(_ server: Server) -> some View {
        Button {
            model.toggleFavorite(server)
        } label: {
            if model.isFavorite(server) {
                Label("Remove from Favorites", systemImage: "star.slash")
            } else {
                Label("Add to Favorites", systemImage: "star")
            }
        }
        .tint(.yellow)
        Button {
            model.shareServer(server)
        } label: {
            Label("Share Server", systemImage: "square.and.arrow.up")
        }
        .tint(.blue)
        Button {
            model.copyLink(of: server)
        } label: {
            Label("Copy Link", systemImage: "link")
        }
        .tint(.gray)
    }

    private func detail(for server: Server) -> String {
        var detail = "\(server.ipaddr):\(server.tcpport)"
        if server.servertype != .LOCAL {
            detail += ", " + String(format: String(localized: "Users: %d, Country: %@", comment: "serverlist"), server.stats_usercount, server.stats_country)
        }
        return detail
    }

    private func iconName(for server: Server) -> String {
        switch server.servertype {
        case .LOCAL:
            return "teamtalk_yellow"
        case .OFFICIAL:
            return "teamtalk_blue"
        case .PUBLIC:
            return "teamtalk_green"
        case .UNOFFICIAL:
            return "teamtalk_orange"
        }
    }

    private func iconAccessibilityLabel(for server: Server) -> String {
        switch server.servertype {
        case .LOCAL:
            return String(localized: "Local server", comment: "serverlist")
        case .OFFICIAL:
            return String(localized: "Official server", comment: "serverlist")
        case .PUBLIC:
            return String(localized: "Public server", comment: "serverlist")
        case .UNOFFICIAL:
            return String(localized: "Unofficial server", comment: "serverlist")
        }
    }
}

// MARK: - Server detail sheet

private struct ServerDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    let detailModel: ServerDetailModel
    let listModel: ServerListModel

    var body: some View {
        NavigationStack {
            ServerDetailView(
                model: detailModel,
                copyJoinCode: {
                    UIPasteboard.general.string = detailModel.server.joincode
                },
                connect: {
                    dismiss()
                    detailModel.apply(to: detailModel.server)
                    listModel.connect(to: detailModel.server)
                },
                delete: {
                    showDeleteAlert = true
                },
                save: {
                    detailModel.apply(to: detailModel.server)
                    listModel.upsertServer(detailModel.server)
                    dismiss()
                }
            )
            .alert("Delete Server", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    listModel.deleteServer(detailModel.server)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Delete \"\(detailModel.server.name)\" from the server list?")
            }
        }
    }
}
