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
