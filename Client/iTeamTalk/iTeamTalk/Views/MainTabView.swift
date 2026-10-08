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

struct MainTabView: View {
    @ObservedObject var model: MainTabModel
    let close: () -> Void
    @State private var saveAlertName = String(localized: "New Server", comment: "Dialog message")
    @State private var selectedTab = 0

    /// The scrub of VoiceOver with the focus where no view answers it, the
    /// navigation bar or the tab bar: back to the Channels tab and, from
    /// there, what the Channels tab does with it.
    private func goBack() -> Bool {
        if selectedTab != 0 {
            selectedTab = 0
        } else if !model.channelListModel.goBack() {
            model.disconnectTapped(dismiss: close)
        }
        return true
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ChannelsTabView(mainModel: model, model: model.channelListModel, close: close)
                /*.accessibilityAction(.magicTap) {
                    model.channelListModel.txBtnAccessibilityAction()
                }*/
            .tabItem {
                Label("Channels", systemImage: "folder")
            }
            .tag(0)

            // Messages tab
            NavigationStack {
                TextMessageView(model: model.channelChatModel)
                    .accessibilityAction(.escape) {
                        selectedTab = 0
                    }
                    /*.accessibilityAction(.magicTap) {
                        model.channelListModel.txBtnAccessibilityAction()
                    }*/
            }
            .tabItem {
                Label("Messages", systemImage: "envelope")
            }
            .tag(1)

            // Files tab
            NavigationStack {
                FileListView(model: model.fileListModel)
                    .accessibilityAction(.escape) {
                        selectedTab = 0
                    }
            }
            .tabItem {
                Label("Files", systemImage: "doc")
            }
            .tag(3)

            // Preferences tab
            NavigationStack {
                PreferencesView(model: model.preferencesModel)
                    .accessibilityAction(.escape) {
                        selectedTab = 0
                    }
                    /*.accessibilityAction(.magicTap) {
                        model.channelListModel.txBtnAccessibilityAction()
                    }*/
            }
            .tabItem {
                Label("Preferences", systemImage: "wrench.and.screwdriver")
            }
            .tag(2)
        }
        .accessibilityAction(.magicTap) {
            model.channelListModel.txBtnAccessibilityAction()
        }
        .onAppear {
            AppDelegate.escapeHandler = goBack
        }
        .onDisappear {
            AppDelegate.escapeHandler = nil
        }
        .background {
            KeyboardShortcutButtons { action in
                model.performKeyboardAction(action)
            }
        }
        .confirmationDialog(
            Text("Send to TeamTalk"),
            isPresented: Binding(
                get: { model.incomingFile != nil },
                set: { if !$0 { model.incomingFile = nil } }
            ),
            titleVisibility: .visible,
            presenting: model.incomingFile
        ) { file in
            if model.fileListModel.canUpload {
                Button("Upload to Channel") {
                    model.uploadIncomingFile(file)
                }
            }
            if model.mediaStreamModel.canStreamAudio || model.mediaStreamModel.canStreamVideo {
                Button("Add to Streaming Playlist") {
                    model.streamIncomingFile(file)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text(verbatim: file.url.lastPathComponent)
        }
        .onAppear {
            model.setup()
            model.onVisibleAppear()
        }
        .onDisappear {
            model.teardown()
        }
        .onReceive(NotificationCenter.default.publisher(for: .iTeamTalkRemoteControl)) { notification in
            model.remoteControl(notification.object as? UIEvent)
        }
        .alert("Error",
               isPresented: Binding(
                get: { model.alertMessage != nil },
                set: { if !$0 { model.alertMessage = nil } }
               )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .alert("Connect to Server",
            isPresented: Binding(
                get: { model.fatalAlertMessage != nil },
                set: { if !$0 { model.fatalAlertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                close()
            }
        } message: {
            Text(model.fatalAlertMessage ?? "")
        }
        .alert("Save Server",
            isPresented: $model.showSaveAlert
        ) {
            TextField("New Server",
                text: $saveAlertName
            )
            Button("No", role: .cancel) {
                model.skipSaveAndDisconnect()
            }
            Button("Yes") {
                model.saveAndDisconnect(name: saveAlertName)
            }
        } message: {
            Text("Save server to server list?")
        }
    }
}

// MARK: - Channels tab

/// The screens opened from the More menu of the channel list
private enum ChannelSheet: Int, Identifiable {
    case allUsers
    case transmission
    case bans
    case accounts

    var id: Int {
        rawValue
    }
}

private struct ChannelsTabView: View {
    @ObservedObject var mainModel: MainTabModel
    @ObservedObject var model: ChannelListModel
    let close: () -> Void
    @State private var showingMediaStream = false
    @State private var channelSheet: ChannelSheet?

    /// The scrub of VoiceOver: one step back in the channel list and, at the
    /// top of the server, out of it, like Disconnect. The buttons of the
    /// navigation bar carry it too, they are not inside the list.
    private func escape() {
        if !model.goBack() {
            mainModel.disconnectTapped(dismiss: close)
        }
    }

    var body: some View {
        NavigationStack(path: $model.navigationPath) {
            ChannelListContainerView(model: model)
                .accessibilityAction(.escape, escape)
                .navigationDestination(for: ChannelListDestination.self) { destination in
                    channelDestinationView(destination)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Disconnect") {
                            mainModel.disconnectTapped(dismiss: close)
                        }
                        .accessibilityHint("Disconnects from the server and goes back to the server list")
                        .accessibilityAction(.escape, escape)
                    }
                    // Three items and no more. With four the last one stopped
                    // answering on the device, a plain button where there had
                    // been a menu. Each has a title besides its symbol: it is
                    // what VoiceOver reads, and what the system shows if it
                    // ever moves an item into a menu of its own.
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            model.toggleSelecting()
                        } label: {
                            Label(model.isSelecting ? LocalizedStringKey("Done selecting") : LocalizedStringKey("Select users"),
                                  systemImage: model.isSelecting ? "checklist.checked" : "checklist")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.tint)
                        }
                        .accessibilityHint(model.isSelecting
                            ? Text("Ends the selection of users")
                            : Text("Lets you choose several users to move, kick or ban them"))
                        .accessibilityAction(.escape, escape)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingMediaStream = true
                        } label: {
                            Label("Stream media file", systemImage: "play.rectangle")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.tint)
                        }
                        .accessibilityHint("Opens the screen to stream audio or video to the channel")
                        .accessibilityAction(.escape, escape)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        // a menu of the system: it follows light and dark by itself
                        Menu {
                            Button {
                                model.showNewChannel()
                            } label: {
                                Label("Create new channel", systemImage: "plus")
                            }
                            Button {
                                channelSheet = .allUsers
                            } label: {
                                Label("All Users", systemImage: "person.3")
                            }
                            if model.canControlTransmission {
                                Button {
                                    channelSheet = .transmission
                                } label: {
                                    Label("Who Can Transmit", systemImage: "mic.badge.plus")
                                }
                            }
                            if model.canBanUsers {
                                Button {
                                    channelSheet = .bans
                                } label: {
                                    Label("Banned Users", systemImage: "nosign")
                                }
                            }
                            if model.isAdministrator {
                                Button {
                                    channelSheet = .accounts
                                } label: {
                                    Label("User Accounts", systemImage: "person.badge.key")
                                }
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.tint)
                        }
                        .accessibilityHint("Opens a menu with more options")
                        .accessibilityAction(.escape, escape)
                    }
                }
                .sheet(item: $channelSheet) { sheet in
                    switch sheet {
                    case .allUsers:
                        AllUsersView(model: model)
                    case .transmission:
                        TransmitControlView(model: model)
                    case .bans:
                        BanListView()
                    case .accounts:
                        UserAccountsView()
                    }
                }
                .sheet(item: $model.channelDetailModel) { detailModel in
                    ChannelDetailSheetView(model: detailModel)
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showingMediaStream) {
                    NavigationStack {
                        MediaStreamView(model: mainModel.mediaStreamModel)
                    }
                    .presentationDragIndicator(.visible)
                }
        }
    }

    @ViewBuilder
    private func channelDestinationView(_ destination: ChannelListDestination) -> some View {
        switch destination {
        case .userDetail(let m):
            UserDetailView(model: m)

        case .textMessage(let m):
            TextMessageView(model: m)
        }
    }
}

// MARK: - Channel detail sheet

private struct ChannelDetailSheetView: View {
    @ObservedObject var model: ChannelDetailModel

    var body: some View {
        NavigationStack {
            ChannelDetailView(model: model, setupCodec: {
                model.audioCodecModel = model.makeAudioCodecModel()
            })
            .navigationDestination(isPresented: Binding(
                get: { model.audioCodecModel != nil },
                set: { if !$0 { model.audioCodecModel = nil } }
            )) {
                if let codecModel = model.audioCodecModel {
                    AudioCodecView(model: codecModel, performAction: { action in
                        model.applyCodecAction(action, codecModel: codecModel)
                    })
                }
            }
        }
    }
}
