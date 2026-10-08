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

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                List {
                    ForEach(model.sections) { section in
                        Section(section.title) {
                            ForEach(section.messages.indices, id: \.self) { index in
                                let message = section.messages[index]
                                let background = appearance.backgroundColor(for: message.msgtype)
                                MessageRow(message: message, background: background)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                    .listRowBackground(background)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .onChange(of: model.sections.count) { _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: model.sections.last?.messages.count ?? 0) { _ in
                    scrollToBottom(proxy)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let section = model.sections.last, !section.messages.isEmpty else { return }
        DispatchQueue.main.async {
            proxy.scrollTo(section.id, anchor: .bottom)
        }
    }
}

private struct MessageRow: View {
    let message: MyTextMessage
    let background: Color

    var body: some View {
        // not the theme's text color: the background stays the same in dark mode
        let textColor = AppearanceModel.textColor(on: background)

        VStack(alignment: .leading, spacing: 6) {
            Text(headerText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(textColor.opacity(0.75))
            Text(message.message)
                .font(.body)
                .foregroundStyle(textColor)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .background(background)
        .accessibilityElement(children: .combine)
        .accessibilityHint(accessibilityHint)
    }

    private var headerText: String {
        switch message.msgtype {
        case .PRIV_IM, .PRIV_IM_MYSELF, .CHAN_IM, .CHAN_IM_MYSELF, .BCAST:
            return "\(limitText(message.nickname)), \(timeText)"
        case .LOGMSG:
            return timeText
        }
    }

    private var accessibilityHint: String {
        "\(headerText). \(messageTypeText)"
    }

    private var messageTypeText: String {
        switch message.msgtype {
        case .PRIV_IM, .PRIV_IM_MYSELF:
            return String(localized: "Private message", comment: "text message type")
        case .CHAN_IM, .CHAN_IM_MYSELF:
            return String(localized: "Channel message", comment: "text message type")
        case .BCAST:
            return String(localized: "Broadcast message", comment: "text message type")
        case .LOGMSG:
            return String(localized: "Log message", comment: "text message type")
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: message.date)
    }
}
