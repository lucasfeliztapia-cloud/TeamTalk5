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

let PREF_APPEARANCE_RECEIVEDCOLOR = "appearance_receivedcolor_preference"
let PREF_APPEARANCE_SENTCOLOR = "appearance_sentcolor_preference"
let PREF_APPEARANCE_INTERFACECOLOR = "appearance_interfacecolor_preference"
let PREF_APPEARANCE_TEXTSIZE = "appearance_textsize_preference"
let PREF_APPEARANCE_FONTDESIGN = "appearance_fontdesign_preference"

enum AppearanceFontDesign: Int, CaseIterable, Identifiable {
    case standard = 0
    case serif
    case rounded
    case monospaced

    var id: Int {
        rawValue
    }

    var design: Font.Design? {
        switch self {
        case .standard:
            return nil
        case .serif:
            return .serif
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .standard:
            return "Standard"
        case .serif:
            return "Serif"
        case .rounded:
            return "Rounded"
        case .monospaced:
            return "Monospaced"
        }
    }
}

/// Applies the chosen font to every text below it.
struct FontDesignModifier: ViewModifier {
    let design: Font.Design?

    func body(content: Content) -> some View {
        if #available(iOS 16.1, *) {
            content.fontDesign(design)
        } else {
            content
        }
    }
}

final class AppearanceModel: ObservableObject {

    static let shared = AppearanceModel()

    static let defaultReceivedColor = Color(red: 1.0, green: 0.627, blue: 0.882)
    static let defaultSentColor = Color(red: 0.54, green: 0.82, blue: 0.94)
    static let defaultInterfaceColor = Color(uiColor: .systemBlue)
    static let broadcastColor = Color(red: 0.831, green: 0.376, blue: 1.0)
    static let logColor = Color(red: 0.86, green: 0.86, blue: 0.86)

    /// One title for each case of DynamicTypeSize, in its order
    static let textSizeTitles: [LocalizedStringKey] = [
        "Extra Small", "Small", "Medium", "Large", "Extra Large", "Extra Extra Large",
        "Extra Extra Extra Large", "Accessibility 1", "Accessibility 2", "Accessibility 3",
        "Accessibility 4", "Accessibility 5"
    ]

    @Published var receivedColor: Color {
        didSet { Self.save(receivedColor, forKey: PREF_APPEARANCE_RECEIVEDCOLOR) }
    }

    @Published var sentColor: Color {
        didSet { Self.save(sentColor, forKey: PREF_APPEARANCE_SENTCOLOR) }
    }

    /// nil keeps the system's own tint
    @Published var interfaceColor: Color? {
        didSet {
            if let interfaceColor {
                Self.save(interfaceColor, forKey: PREF_APPEARANCE_INTERFACECOLOR)
            } else {
                UserDefaults.standard.removeObject(forKey: PREF_APPEARANCE_INTERFACECOLOR)
            }
        }
    }

    /// 0 follows the text size of the system, otherwise the position of the
    /// size in DynamicTypeSize counting from 1
    @Published var textSizeIndex: Int {
        didSet { UserDefaults.standard.set(textSizeIndex, forKey: PREF_APPEARANCE_TEXTSIZE) }
    }

    @Published var fontDesign: AppearanceFontDesign {
        didSet { UserDefaults.standard.set(fontDesign.rawValue, forKey: PREF_APPEARANCE_FONTDESIGN) }
    }

    private init() {
        let defaults = UserDefaults.standard
        receivedColor = Self.load(forKey: PREF_APPEARANCE_RECEIVEDCOLOR) ?? Self.defaultReceivedColor
        sentColor = Self.load(forKey: PREF_APPEARANCE_SENTCOLOR) ?? Self.defaultSentColor
        interfaceColor = Self.load(forKey: PREF_APPEARANCE_INTERFACECOLOR)
        textSizeIndex = defaults.integer(forKey: PREF_APPEARANCE_TEXTSIZE)
        fontDesign = AppearanceFontDesign(rawValue: defaults.integer(forKey: PREF_APPEARANCE_FONTDESIGN)) ?? .standard
    }

    func restoreDefaults() {
        receivedColor = Self.defaultReceivedColor
        sentColor = Self.defaultSentColor
        interfaceColor = nil
        textSizeIndex = 0
        fontDesign = .standard
    }

    /// A range and not a single size, so the same modifier serves "follow the
    /// system" and a fixed size: swapping modifiers would rebuild every view.
    var dynamicTypeRange: ClosedRange<DynamicTypeSize> {
        let sizes = DynamicTypeSize.allCases
        guard textSizeIndex >= 1, textSizeIndex <= sizes.count else {
            return DynamicTypeSize.xSmall...DynamicTypeSize.accessibility5
        }
        let size = sizes[textSizeIndex - 1]
        return size...size
    }

    func backgroundColor(for msgtype: MsgType) -> Color {
        switch msgtype {
        case .PRIV_IM, .CHAN_IM:
            return receivedColor
        case .PRIV_IM_MYSELF, .CHAN_IM_MYSELF:
            return sentColor
        case .BCAST:
            return Self.broadcastColor
        case .LOGMSG:
            return Self.logColor
        }
    }

    /// Black or white, whichever is easier to read on the background. The text
    /// cannot follow the light or dark theme because the background does not.
    static func textColor(on background: Color) -> Color {
        relativeLuminance(of: background) > 0.179 ? .black : .white
    }

    private static func components(of color: Color) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (min(max(red, 0), 1), min(max(green, 0), 1), min(max(blue, 0), 1))
    }

    private static func relativeLuminance(of color: Color) -> Double {
        func linear(_ value: CGFloat) -> Double {
            let value = Double(value)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let rgb = components(of: color)
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    private static func save(_ color: Color, forKey key: String) {
        let rgb = components(of: color)
        let hex = String(format: "%02X%02X%02X",
                         Int((rgb.red * 255).rounded()),
                         Int((rgb.green * 255).rounded()),
                         Int((rgb.blue * 255).rounded()))
        UserDefaults.standard.set(hex, forKey: key)
    }

    private static func load(forKey key: String) -> Color? {
        guard let hex = UserDefaults.standard.string(forKey: key), hex.count == 6,
              let value = UInt32(hex, radix: 16) else {
            return nil
        }
        return Color(red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }
}
