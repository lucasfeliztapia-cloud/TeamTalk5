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

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Favorite servers

struct FavoritesEntry: TimelineEntry {
    let date: Date
    let favorites: [SharedFavorite]
    // false when the app and the widget have no group to share through
    let isShared: Bool
}

struct FavoritesProvider: TimelineProvider {
    func placeholder(in context: Context) -> FavoritesEntry {
        FavoritesEntry(date: Date(), favorites: [], isShared: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (FavoritesEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoritesEntry>) -> Void) {
        // the app reloads the widget when the favorites change
        completion(Timeline(entries: [entry()], policy: .never))
    }

    private func entry() -> FavoritesEntry {
        FavoritesEntry(date: Date(), favorites: SharedStore.favorites, isShared: SharedStore.defaults != nil)
    }
}

struct FavoriteServersWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedStore.favoritesWidgetKind, provider: FavoritesProvider()) { entry in
            FavoriteServersView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Favorite Servers")
        .description("Connect to one of your favorite servers with a tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct FavoriteServersView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FavoritesEntry

    private var limit: Int {
        switch family {
        case .systemMedium:
            return 3
        case .systemLarge:
            return 7
        default:
            return 1
        }
    }

    var body: some View {
        if entry.favorites.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "star")
                    .font(.title2)
                    .accessibilityHidden(true)
                if entry.isShared {
                    Text("Mark a server as favorite in TeamTalk")
                } else {
                    Text("Open TeamTalk to see your favorite servers")
                }
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
        } else if family == .systemSmall, let favorite = entry.favorites.first {
            // a small widget is one link as a whole
            VStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                Text(favorite.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Connect to \(favorite.name)"))
            .widgetURL(favorite.url)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entry.favorites.prefix(limit)) { favorite in
                    if let url = favorite.url {
                        Link(destination: url) {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .accessibilityHidden(true)
                                Text(favorite.name)
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(.fill.secondary, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .accessibilityLabel(Text("Connect to \(favorite.name)"))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Controls for Control Center, the Lock Screen and the Action button

@available(iOS 18.0, *)
struct TransmitControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SharedStore.transmitControlKind, provider: Provider()) { isOn in
            ControlWidgetToggle("Talk in TeamTalk", isOn: isOn, action: SetTransmissionIntent()) { isOn in
                Label(isOn ? LocalizedStringKey("Transmitting") : LocalizedStringKey("Not transmitting"),
                      systemImage: isOn ? "mic.fill" : "mic.slash.fill")
            }
            .tint(.red)
        }
        .displayName("Talk in TeamTalk")
        .description("Turns your transmission on and off while connected to a server.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            false
        }

        func currentValue() async throws -> Bool {
            SharedStore.defaults?.bool(forKey: SharedStore.transmittingKey) ?? false
        }
    }
}

@available(iOS 18.0, *)
struct SpeakersControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: SharedStore.speakersControlKind, provider: Provider()) { isOn in
            ControlWidgetToggle("TeamTalk Speakers", isOn: isOn, action: SetSpeakersIntent()) { isOn in
                Label(isOn ? LocalizedStringKey("On") : LocalizedStringKey("Muted"),
                      systemImage: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
        }
        .displayName("TeamTalk Speakers")
        .description("Mutes everyone and brings them back while connected to a server.")
    }

    struct Provider: ControlValueProvider {
        var previewValue: Bool {
            true
        }

        func currentValue() async throws -> Bool {
            !(SharedStore.defaults?.bool(forKey: SharedStore.deafenedKey) ?? false)
        }
    }
}
