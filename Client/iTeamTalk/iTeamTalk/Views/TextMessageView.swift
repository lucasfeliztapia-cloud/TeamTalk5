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

struct TextMessageView: View {
    @ObservedObject var model: TextMessageModel
    @ObservedObject private var appearance = AppearanceModel.shared
    @FocusState private var isComposing: Bool
    @State private var showingBroadcast = false
    @State private var broadcastText = ""
    @AppStorage(PREF_DISPLAY_MSGDETAILS) private var messageDetails = MessageDetails.nameAndTime.rawValue
    @AppStorage(PREF_DISPLAY_MSGDETAILSAFTER) private var detailsAfter = false
    @AppStorage(PREF_DISPLAY_MSGFOCUS) private var followsNewMessages = false
    @AccessibilityFocusState private var focusedMessage: UUID?

    private var details: MessageDetails {
        MessageDetails(rawValue: messageDetails) ?? .nameAndTime
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(model.sections) { section in
                        Section {
                            ForEach(section.messages, id: \.id) { message in
                                let background = appearance.backgroundColor(for: message.msgtype)
                                MessageRow(message: message, background: background,
                                           design: message.msgtype == .LOGMSG
                                               ? appearance.eventFontDesign
                                               : appearance.fontDesign.design,
                                           details: details, detailsAfter: detailsAfter)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    .listRowBackground(background)
                                    .accessibilityFocused($focusedMessage, equals: message.id)
                            }
                        } header: {
                            // the name heads the group only when the messages
                            // do not carry it: it was said twice
                            if !details.showsName {
                                Text(section.title)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                // the messages can have a text size of their own
                .dynamicTypeSize(appearance.messageDynamicTypeRange)
                .onChange(of: model.sections.last?.messages.last?.id) { newest in
                    messageAdded(newest, proxy: proxy)
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $model.composedText)
                        .focused($isComposing)
                        .frame(minHeight: 40, maxHeight: 96)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel("Message")
                        .onChange(of: model.composedText) { text in
                            sendOnReturnIfNeeded(text)
                        }

                    if model.composedText.isEmpty {
                        Text("Type text here")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                Button("Send") {
                    if model.composedText.isEmpty {
                        isComposing = false
                    } else {
                        model.sendMessage()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.bar)
        }
        .navigationTitle(model.title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if model.canBroadcast {
                    Button {
                        showingBroadcast = true
                    } label: {
                        Image(systemName: "megaphone")
                    }
                    .accessibilityLabel("Send broadcast message")
                }
            }
        }
        .alert("Broadcast Message", isPresented: $showingBroadcast) {
            TextField("Message", text: $broadcastText)
            Button("Send") {
                model.sendBroadcast(broadcastText)
                broadcastText = ""
            }
            Button("Cancel", role: .cancel) {
                broadcastText = ""
            }
        } message: {
            Text("It is sent to every user of the server")
        }
        .onDisappear {
            model.clearUnreadMessages()
        }
    }

    private func sendOnReturnIfNeeded(_ text: String) {
        let defaults = UserDefaults.standard
        let sendOnReturn = defaults.object(forKey: PREF_GENERAL_SENDONRETURN) == nil || defaults.bool(forKey: PREF_GENERAL_SENDONRETURN)
        guard sendOnReturn, text.contains("\n") else { return }
        model.composedText = text.replacingOccurrences(of: "\n", with: "")
        model.sendMessage()
    }

    /// A message was added at the end. Without VoiceOver the list follows it,
    /// as a chat does. With VoiceOver the list moves only when the user wants
    /// the cursor on the newest message: scrolling takes the row under the
    /// cursor off the screen, and VoiceOver then went to the top.
    private func messageAdded(_ newest: UUID?, proxy: ScrollViewProxy) {
        guard let newest, let message = model.sections.last?.messages.last else { return }
        guard UIAccessibility.isVoiceOverRunning else {
            scrollToBottom(newest, proxy: proxy)
            return
        }
        guard followsNewMessages else { return }
        // not while a message is being written, unless it is the one just sent
        let mine = message.msgtype == .CHAN_IM_MYSELF || message.msgtype == .PRIV_IM_MYSELF
        guard mine || !isComposing else { return }
        scrollToBottom(newest, proxy: proxy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            focusedMessage = newest
        }
    }

    private func scrollToBottom(_ newest: UUID, proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(newest, anchor: .bottom)
        }
    }
}

private struct MessageRow: View {
    let message: MyTextMessage
    let background: Color
    // the server events can have a font of their own
    let design: Font.Design?
    // who and when: how much of it, and on which side of the text
    let details: MessageDetails
    let detailsAfter: Bool

    @Environment(\.openURL) private var openURL

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        // not the theme's text color: the background stays the same in dark mode
        let textColor = AppearanceModel.textColor(on: background)
        let detailsText = self.detailsText

        // VoiceOver reads the row in this order, and nothing else: the hint
        // that repeated the name and the time is gone
        VStack(alignment: .leading, spacing: 6) {
            if !detailsText.isEmpty && !detailsAfter {
                detailsLine(detailsText, color: textColor)
            }
            Text(linkedMessage)
                .font(.body)
                .foregroundStyle(textColor)
                // links take the tint: keep them readable on the bubble
                .tint(textColor)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if !detailsText.isEmpty && detailsAfter {
                detailsLine(detailsText, color: textColor)
            }
        }
        .modifier(FontDesignModifier(design: design))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .background(background)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(action: copyMessage) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            if let link = links.first {
                Button {
                    openURL(link.url)
                } label: {
                    Label("Open Link", systemImage: "safari")
                }
            }
        }
        .accessibilityAction(named: "Copy", copyMessage)
        .accessibilityActions {
            if let link = links.first {
                Button("Open Link") {
                    openURL(link.url)
                }
            }
        }
    }

    private func copyMessage() {
        UIPasteboard.general.string = message.message
        announceForAccessibility(String(localized: "Copied", comment: "text message"))
    }

    private var links: [(range: Range<String.Index>, url: URL)] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let text = message.message
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let url = match.url, let range = Range(match.range, in: text) else { return nil }
            return (range, url)
        }
    }

    /// The message with its web addresses turned into links
    private var linkedMessage: AttributedString {
        var attributed = AttributedString(message.message)
        for link in links {
            guard let lower = AttributedString.Index(link.range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(link.range.upperBound, within: attributed) else { continue }
            attributed[lower..<upper].link = link.url
            attributed[lower..<upper].swiftUI.underlineStyle = Text.LineStyle.single
        }
        return attributed
    }

    private func detailsLine(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(color.opacity(0.75))
    }

    /// Who and when, as much of it as the user wants. A broadcast always
    /// says that it is one: nothing else tells it from a channel message.
    private var detailsText: String {
        var parts = [String]()
        switch message.msgtype {
        case .BCAST:
            parts.append(String(localized: "Broadcast Message", comment: "text message type"))
            if details.showsName {
                parts.append(limitText(message.nickname))
            }
        case .PRIV_IM, .PRIV_IM_MYSELF, .CHAN_IM, .CHAN_IM_MYSELF:
            if details.showsName {
                parts.append(limitText(message.nickname))
            }
        case .LOGMSG:
            break
        }
        if details.showsTime {
            parts.append(MessageRow.timeFormatter.string(from: message.date))
        }
        return parts.joined(separator: ", ")
    }
}
