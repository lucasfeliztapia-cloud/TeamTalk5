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

/// The channels of the server as a tree: a channel with channels inside starts
/// collapsed and opens when it is chosen. Searching shows the matches as a flat list.
struct ChannelPickerView: View {
    let channels: [ChannelNode]
    let confirmTitle: LocalizedStringKey
    let choose: (INT32) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection: INT32?
    @State private var expanded = Set<INT32>()
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List(visibleChannels) { channel in
                row(channel)
            }
            .searchable(text: $searchText, prompt: "Search channels")
            .navigationTitle("Choose Channel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) {
                        if let selection {
                            choose(selection)
                        }
                        dismiss()
                    }
                    .disabled(selection == nil)
                }
            }
            .onAppear {
                // the first level in sight, the rest collapsed
                if expanded.isEmpty {
                    expanded = Set(channels.filter { $0.depth == 0 }.map { $0.id })
                }
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var visibleChannels: [ChannelNode] {
        if isSearching {
            let query = searchText.trimmingCharacters(in: .whitespaces)
            return channels.filter {
                $0.name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }

        // the list is in tree order, so everything deeper than a collapsed
        // channel that follows it is inside it
        var visible = [ChannelNode]()
        var collapsedDepth: Int?
        for channel in channels {
            if let depth = collapsedDepth {
                if channel.depth > depth {
                    continue
                }
                collapsedDepth = nil
            }
            visible.append(channel)
            if channel.hasChildren && !expanded.contains(channel.id) {
                collapsedDepth = channel.depth
            }
        }
        return visible
    }

    private func row(_ channel: ChannelNode) -> some View {
        let isExpanded = expanded.contains(channel.id)
        let showsTree = !isSearching

        return Button {
            selection = channel.id
            if showsTree && channel.hasChildren {
                if isExpanded {
                    expanded.remove(channel.id)
                } else {
                    expanded.insert(channel.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                if showsTree {
                    Image(systemName: channel.hasChildren ? (isExpanded ? "chevron.down" : "chevron.right") : "circle.fill")
                        .font(channel.hasChildren ? .footnote.weight(.semibold) : .system(size: 5))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.name)
                        .foregroundStyle(.primary)
                    if isSearching && channel.path != channel.name {
                        Text(channel.path)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if channel.isCurrent {
                        Text("Your channel")
                            .font(.footnote)
                            .foregroundStyle(.tint)
                    }
                }

                Spacer(minLength: 12)

                Text(verbatim: String(channel.userCount))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)

                if selection == channel.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.leading, showsTree ? CGFloat(channel.depth) * 18 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(channel.name)
        .accessibilityValue(accessibilityValue(channel, isExpanded: isExpanded))
        .accessibilityAddTraits(selection == channel.id ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityValue(_ channel: ChannelNode, isExpanded: Bool) -> String {
        var parts = [String]()
        if !isSearching && channel.hasChildren {
            parts.append(isExpanded
                ? String(localized: "Expanded", comment: "channel picker")
                : String(localized: "Collapsed", comment: "channel picker"))
        }
        if isSearching && channel.path != channel.name {
            parts.append(channel.path)
        }
        parts.append(channel.userCount == 1
            ? String(localized: "1 user", comment: "channel picker")
            : String(format: String(localized: "%d users", comment: "channel picker"), channel.userCount))
        if channel.isCurrent {
            parts.append(String(localized: "Your channel", comment: "channel picker"))
        }
        return parts.joined(separator: ", ")
    }
}
