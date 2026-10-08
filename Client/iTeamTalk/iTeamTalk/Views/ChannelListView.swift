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

// MARK: - Container view

struct ChannelListContainerView: View {
    @ObservedObject var model: ChannelListModel
    @ObservedObject private var appearance = AppearanceModel.shared
    @State private var isPressingTalkButton = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isSearching {
                // Ours and not the scopes of the search field: those only came
                // up after clearing the text, when there is nothing to filter.
                Picker("Search channels and users", selection: $model.searchScope) {
                    Text("All").tag(ChannelSearchScope.all)
                    Text("Channels").tag(ChannelSearchScope.channels)
                    Text("Users").tag(ChannelSearchScope.users)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            ChannelListView(model: model)
            if model.isSelecting {
                selectionBar
            }
            HStack(spacing: 0) {
            Text("Talk")
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                // only the button: a color fills the safe area unless told otherwise,
                // and it showed under the tab bar
                .background(talkColor, ignoresSafeAreaEdges: [])
                .foregroundStyle(AppearanceModel.textColor(on: talkColor))
                .fontWeight(.semibold)
                .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressingTalkButton else { return }
                        isPressingTalkButton = true
                        model.txBtnDown()
                    }
                    .onEnded { _ in
                        guard isPressingTalkButton else { return }
                        isPressingTalkButton = false
                        model.txBtnUp()
                    }
            )
            .accessibilityLabel("Push to Talk")
            .accessibilityHint(model.pttHint)
            .accessibilityValue(model.isTransmitting
                ? Text("Active")
                : Text("Inactive"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.magicTap) {
                model.txBtnAccessibilityAction()
            }
            outputMenu
            deafenButton
            }
            .background(Color(uiColor: .systemBackground))
        }
        .navigationTitle(model.navigationTitle)
        .searchable(text: $model.searchText, prompt: "Search channels and users")
        .sheet(item: $model.moveRequest) { request in
            ChannelPickerView(channels: model.channelNodes(), confirmTitle: "Move") { channelID in
                model.moveUsers(request.userIDs, to: channelID)
            }
        }
        .alert("Confirm",
            isPresented: Binding(
                get: { model.moderationRequest != nil },
                set: { if !$0 { model.moderationRequest = nil } }
            ),
            presenting: model.moderationRequest
        ) { request in
            if request.action == .ban {
                Button("Ban", role: .destructive) {
                    model.confirmModeration(request)
                }
            } else {
                Button("Kick", role: .destructive) {
                    model.confirmModeration(request)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text(model.moderationMessage(request))
        }
        .alert("Enter Password", isPresented: $model.showingJoinPasswordAlert) {
            SecureField("Password", text: $model.joinPassword)
            Button("Join") { model.confirmJoinWithPassword() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Password")
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

private extension ChannelListContainerView {

    /// Quick choice between the speaker and the earpiece or headset. The full
    /// setup stays in Preferences.
    var outputMenu: some View {
        Menu {
            Picker("Audio Output", selection: Binding(
                get: { model.speakerOutput },
                set: { model.setSpeakerOutput($0) }
            )) {
                Label("Speaker", systemImage: "speaker.wave.3.fill").tag(true)
                Label("Earpiece or Headset", systemImage: "ear").tag(false)
            }
        } label: {
            Image(systemName: "airplayaudio")
                .font(.title3)
                .frame(width: 56, height: 50)
                .background(.bar, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
        }
        .accessibilityLabel("Audio Output")
        .accessibilityValue(model.speakerOutput ? Text("Speaker") : Text("Earpiece or Headset"))
    }

    var talkColor: Color {
        model.isTransmitting ? appearance.talkActiveColor : appearance.talkIdleColor
    }

    /// By default white with a black speaker while listening and black with a
    /// white speaker while all incoming audio is muted.
    var deafenButton: some View {
        let background = model.isDeafened ? appearance.speakersMutedColor : appearance.speakersOnColor

        return Button(action: model.toggleDeafen) {
            Image(systemName: model.isDeafened ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.title3)
                .foregroundStyle(AppearanceModel.textColor(on: background))
                .frame(width: 64, height: 50)
                .background(background, ignoresSafeAreaEdges: [])
                .overlay(Rectangle().stroke(Color.gray, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Speakers")
        .accessibilityValue(model.isDeafened ? Text("Muted") : Text("On"))
        .accessibilityHint("Mutes or unmutes everything you hear from the server")
    }

    var selectionBar: some View {
        let selected = model.selectedUserIDs

        return HStack(spacing: 16) {
            Text(model.selectionSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Move") {
                model.requestMove(userIDs: selected)
            }
            .disabled(selected.isEmpty || !model.canMoveUsers)
            Button("Kick") {
                model.requestModeration(.kick, userIDs: selected)
            }
            .disabled(selected.isEmpty)
            Button("Ban") {
                model.requestModeration(.ban, userIDs: selected)
            }
            .disabled(selected.isEmpty)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(.bar)
    }
}

// MARK: - List view

struct ChannelListView: View {
    @ObservedObject var model: ChannelListModel

    var body: some View {
        List(model.rows) { row in
            switch row {
            case .join:
                Button(action: model.joinCurrentChannel) {
                    Text("Join this channel")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

            case .header(let title):
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)

            case .user(let user):
                let details = model.userDetails(user)
                let isMoveSelected = model.isMoveUserSelected(userid: user.nUserID)
                HStack(spacing: 10) {
                    if model.isSelecting {
                        Image(systemName: isMoveSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isMoveSelected ? Color.accentColor : Color.secondary)
                            .accessibilityHidden(true)
                    }

                    Image(details.iconName)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .accessibilityLabel(details.iconAccessibilityLabel)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(details.title)
                            .font(.body)
                            .lineLimit(1)
                        if let subtitle = details.subtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    if isMoveSelected && !model.isSelecting {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if !model.isSelecting {
                        Button {
                            model.showTextMessages(userid: user.nUserID)
                        } label: {
                            Image(details.messageIconName)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Text Messaging")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isMoveSelected ? .isSelected : [])
                // Activating a combined row presses the button inside it, which
                // opens the private messages. Stated here so that selecting wins.
                .accessibilityAction {
                    // a search result goes to where the user is
                    if model.isSelecting || model.isSearching {
                        model.selectRow(.user(user))
                    } else {
                        model.showTextMessages(userid: user.nUserID)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectRow(.user(user))
                }
                .contextMenu {
                    userMenu(user)
                }
                .accessibilityAction(named: "Show user details") {
                    model.showUserDetail(userid: user.nUserID)
                }
                .accessibilityAction(named: "Go to Their Channel") {
                    model.goToChannel(id: user.nChannelID)
                }
                .accessibilityAction(named: "Message this user") {
                    model.showTextMessages(userid: user.nUserID)
                }
                .accessibilityAction(named: "Mute") {
                    model.muteUser(userid: user.nUserID)
                }
                .accessibilityAction(named: model.moveUserActionTitle(userid: user.nUserID)) {
                    model.moveUser(userid: user.nUserID)
                }
                .accessibilityAction(named: "Kick user") {
                    model.kickUser(userid: user.nUserID)
                }
                .accessibilityAction(named: "Ban user") {
                    model.banUser(userid: user.nUserID)
                }

            case .channel(let channel):
                let details = model.channelDetails(channel)
                HStack(spacing: 10) {
                    Image(details.iconName)
                        .resizable()
                        .frame(width: 36, height: 36)
                        .accessibilityLabel(details.iconAccessibilityLabel)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(limitText(details.title))
                            .font(.body)
                            .foregroundStyle(details.isParent ? .secondary : .primary)
                            .lineLimit(1)
                        if let subtitle = details.subtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 12)

                    if !model.isSelecting {
                        Button(details.actionTitle) {
                            model.showChannelDetail(channelID: channel.nChannelID)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint(model.moveDestinationAccessibilityHint())
                // Activating a combined row presses the button inside it, which
                // opens the properties of the channel. With VoiceOver a channel
                // is entered like with a tap, and its properties are an action.
                .accessibilityAction {
                    model.selectRow(.channel(channel))
                }
                .accessibilityAction(named: details.actionTitle) {
                    model.showChannelDetail(channelID: channel.nChannelID)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selectRow(.channel(channel))
                }
                .accessibilityAction(named: "Expand") {
                    model.selectRow(.channel(channel))
                }
                .accessibilityAction(named: "Move users here") {
                    model.moveIntoChannel(channelID: channel.nChannelID)
                }
                .accessibilityAction(named: "Join channel") {
                    model.joinChannelFromAccessibility(channelID: channel.nChannelID)
                }
            }
        }
    }

    /// The actions VoiceOver offers on a user, for people who use the screen.
    @ViewBuilder
    private func userMenu(_ user: User) -> some View {
        if user.nChannelID > 0 && user.nChannelID != model.curchannel.nChannelID {
            Button {
                model.goToChannel(id: user.nChannelID)
            } label: {
                Label("Go to Their Channel", systemImage: "arrow.turn.down.right")
            }
        }
        Button {
            model.showTextMessages(userid: user.nUserID)
        } label: {
            Label("Private Message", systemImage: "message")
        }
        Button {
            model.showUserDetail(userid: user.nUserID)
        } label: {
            Label("User Details", systemImage: "person.crop.circle")
        }
        Button {
            model.muteUser(userid: user.nUserID)
        } label: {
            Label("Mute", systemImage: "speaker.slash")
        }
        if model.canMoveUsers {
            Button {
                model.requestMove(userIDs: [user.nUserID])
            } label: {
                Label("Move", systemImage: "arrow.right.circle")
            }
        }
        if model.canKickUser(user) {
            Button(role: .destructive) {
                model.requestModeration(.kick, userIDs: [user.nUserID])
            } label: {
                Label("Kick", systemImage: "person.fill.xmark")
            }
        }
        if model.canBanUser(user) {
            Button(role: .destructive) {
                model.requestModeration(.ban, userIDs: [user.nUserID])
            } label: {
                Label("Ban", systemImage: "nosign")
            }
        }
    }
}

// MARK: - Detail structs

struct ChannelUserDetails {
    let title: String
    let subtitle: String?
    let iconName: String
    let iconAccessibilityLabel: String
    let messageIconName: String
}

struct ChannelDisplayDetails {
    let title: String
    let subtitle: String?
    let iconName: String
    let iconAccessibilityLabel: String
    let actionTitle: String
    let isParent: Bool
}
