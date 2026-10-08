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

// Compiled into both the app and the Live Activity extension.

import ActivityKit
import AppIntents
import Foundation
import SwiftUI

@available(iOS 17.0, *)
struct TeamTalkActivityAttributes: ActivityAttributes {

    struct ContentState: Codable, Hashable {
        var statusText: String
        var isConnected: Bool
        var isTransmitting: Bool
        var isDeafened: Bool

        // "RRGGBB" of the button in its current state, chosen in the app
        var talkColor: String
        var speakersColor: String

        // the media file being streamed, empty when there is none
        var streamName: String
        var isStreamPaused: Bool
    }

    var serverName: String

    // The extension has no translations of its own, so the app passes the
    // texts it shows and reads aloud already translated.
    var transmitLabel: String
    var transmitOnText: String
    var transmitOffText: String
    var speakersLabel: String
    var speakersOnText: String
    var speakersMutedText: String
    var streamPauseLabel: String
    var streamResumeLabel: String
    var streamStopLabel: String
}

/// A color the app hands over as "RRGGBB", and black or white to draw on it.
struct ActivityColor {
    let color: Color
    let text: Color

    init(hex: String, fallback: Color) {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else {
            color = fallback
            text = .white
            return
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        color = Color(red: red, green: green, blue: blue)

        func linear(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        text = luminance > 0.179 ? .black : .white
    }
}

/// What the buttons of the Live Activity do. Set by the app; the intents run
/// in the app's process, so in the extension these stay empty.
enum LiveActivityActions {
    static var toggleTransmission: (() -> Void)?
    static var toggleDeafen: (() -> Void)?
    static var toggleStreamPause: (() -> Void)?
    static var stopStream: (() -> Void)?

    // from the controls, which say the state they want
    static var setTransmission: ((Bool) -> Void)?
    static var setSpeakers: ((Bool) -> Void)?
}

/// What the app shares with its widgets and controls. They all belong to an
/// app group named after the app: "group." and its bundle identifier.
enum SharedStore {

    static let connectedKey = "connected"
    static let transmittingKey = "transmitting"
    static let deafenedKey = "deafened"
    static let favoritesKey = "favorites"

    static let favoritesWidgetKind = "dk.bearware.iTeamTalk.favorites"
    static let transmitControlKind = "dk.bearware.iTeamTalk.transmit"
    static let speakersControlKind = "dk.bearware.iTeamTalk.speakers"

    /// nil when the app was signed without its app group
    static let defaults: UserDefaults? = {
        var bundle = Bundle.main
        if bundle.bundleURL.pathExtension == "appex" {
            // an extension lives in PlugIns, inside the app
            let app = bundle.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            guard let appBundle = Bundle(url: app) else { return nil }
            bundle = appBundle
        }
        guard let identifier = bundle.bundleIdentifier else { return nil }

        let group = "group." + identifier
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) != nil else {
            return nil
        }
        return UserDefaults(suiteName: group)
    }()

    static var favorites: [SharedFavorite] {
        get {
            guard let data = defaults?.data(forKey: favoritesKey) else { return [] }
            return (try? JSONDecoder().decode([SharedFavorite].self, from: data)) ?? []
        }
        set {
            defaults?.set(try? JSONEncoder().encode(newValue), forKey: favoritesKey)
        }
    }

    /// Nothing is connected when the app starts
    static func resetConnection() {
        defaults?.set(false, forKey: connectedKey)
        defaults?.set(false, forKey: transmittingKey)
        defaults?.set(false, forKey: deafenedKey)
    }
}

/// A favorite server as the widget shows it: its name and address, never its account.
struct SharedFavorite: Codable, Hashable, Identifiable {
    var name: String
    var host: String
    var tcpPort: Int
    var udpPort: Int
    var encrypted: Bool

    var id: String {
        "\(host):\(tcpPort)"
    }

    /// Opens the app, which connects with the server it has saved for this address
    var url: URL? {
        var components = URLComponents()
        components.scheme = "tt"
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "tcpport", value: String(tcpPort)),
            URLQueryItem(name: "udpport", value: String(udpPort)),
            URLQueryItem(name: "encrypted", value: encrypted ? "1" : "0"),
            URLQueryItem(name: "saved", value: "1")
        ]
        return components.url
    }
}

@available(iOS 17.0, *)
struct ToggleStreamPauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume Streaming"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LiveActivityActions.toggleStreamPause?()
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct StopStreamIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop Streaming"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LiveActivityActions.stopStream?()
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct ToggleTransmissionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Transmission"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LiveActivityActions.toggleTransmission?()
        }
        return .result()
    }
}

@available(iOS 17.0, *)
struct ToggleDeafenIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Speakers"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            LiveActivityActions.toggleDeafen?()
        }
        return .result()
    }
}

/// From a control: transmission on or off
@available(iOS 18.0, *)
struct SetTransmissionIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Transmission"

    @Parameter(title: "Transmitting")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let enable = value
        await MainActor.run {
            LiveActivityActions.setTransmission?(enable)
        }
        return .result()
    }
}

/// From a control: speakers on, or everyone muted
@available(iOS 18.0, *)
struct SetSpeakersIntent: SetValueIntent, LiveActivityIntent {
    static var title: LocalizedStringResource = "Speakers"

    @Parameter(title: "Speakers On")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let on = value
        await MainActor.run {
            LiveActivityActions.setSpeakers?(on)
        }
        return .result()
    }
}
