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

    var body: some View {
        TabView {
            ChannelsTabView(mainModel: model, model: model.channelListModel, close: close)
                /*.accessibilityAction(.magicTap) {
                    model.channelListModel.txBtnAccessibilityAction()
                }*/
            .tabItem {
                Label("Channels", image: "channels")
            }
            .tag(0)

            // Messages tab
            NavigationStack {
                TextMessageView(model: model.channelChatModel)
                    /*.accessibilityAction(.magicTap) {
                        model.channelListModel.txBtnAccessibilityAction()
                    }*/
            }
            .tabItem {
                Label("Messages", image: "messages")
            }
            .tag(1)

            // Files tab
            NavigationStack {
                FileListView(model: model.fileListModel)
            }
            .tabItem {
                Label("Files", image: "files")
            }
            .tag(3)

            // Preferences tab
            NavigationStack {
                PreferencesView(model: model.preferencesModel)
                    /*.accessibilityAction(.magicTap) {
                        model.channelListModel.txBtnAccessibilityAction()
                    }*/
            }
            .tabItem {
                Label("Preferences", image: "setup")
            }
            .tag(2)
        }
        .accessibilityAction(.magicTap) {
            model.channelListModel.txBtnAccessibilityAction()
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

    var id: Int {
        rawValue
    }
}

private struct ChannelsTabView: View {
    @ObservedObject var mainModel: MainTabModel
    @ObservedObject var model: ChannelListModel
    let close: () -> Void
    @State private var showingMediaStream = false
    @State private var showingMoreMenu = false
    @State private var channelSheet: ChannelSheet?
    @State private var pendingSheet: ChannelSheet?

    var body: some View {
        NavigationStack(path: $model.navigationPath) {
            ChannelListContainerView(model: model)
                .navigationDestination(for: ChannelListDestination.self) { destination in
                    channelDestinationView(destination)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Disconnect") {
                            mainModel.disconnectTapped(dismiss: close)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            model.toggleSelecting()
                        } label: {
                            Image(systemName: model.isSelecting ? "checklist.checked" : "checklist")
                        }
                        // on the button, not on the image: VoiceOver was reading the
                        // name of the symbol, "selected", in front of the label
                        .accessibilityLabel(model.isSelecting ? Text("Done selecting") : Text("Select users"))
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingMediaStream = true
                        } label: {
                            Image(systemName: "play.rectangle")
                                .accessibilityLabel("Stream media file")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            model.showNewChannel()
                        } label: {
                            Image(systemName: "plus")
                                .accessibilityLabel("Create new channel")
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingMoreMenu = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("More")
                    }
                }
                .sheet(isPresented: $showingMoreMenu, onDismiss: {
                    // one sheet at a time: the chosen screen opens once the menu is gone
                    channelSheet = pendingSheet
                    pendingSheet = nil
                }) {
                    MoreMenuView(model: model) { sheet in
                        pendingSheet = sheet
                        showingMoreMenu = false
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

// MARK: - More menu

/// The More menu of the channel list. A screen of the app and not a menu of
/// the system, whose colors cannot be chosen: these come from Appearance.
private struct MoreMenuView: View {
    @ObservedObject var model: ChannelListModel
    @ObservedObject private var appearance = AppearanceModel.shared
    let choose: (ChannelSheet) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("More")
                .font(.headline)
                .foregroundStyle(appearance.resolvedMenuText)
                .padding(.top, 22)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            List {
                row("All Users", systemImage: "person.3", sheet: .allUsers)
                if model.canControlTransmission {
                    row("Who Can Transmit", systemImage: "mic.badge.plus", sheet: .transmission)
                }
                if model.canBanUsers {
                    row("Banned Users", systemImage: "nosign", sheet: .bans)
                }
                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .foregroundStyle(appearance.resolvedMenuText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(appearance.resolvedMenuBackground)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(appearance.resolvedMenuBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func row(_ title: LocalizedStringKey, systemImage: String, sheet: ChannelSheet) -> some View {
        Button {
            choose(sheet)
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(appearance.resolvedMenuText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowBackground(appearance.resolvedMenuBackground)
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
