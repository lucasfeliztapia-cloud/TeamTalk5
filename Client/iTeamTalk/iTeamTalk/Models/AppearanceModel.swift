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
let PREF_APPEARANCE_TALKIDLECOLOR = "appearance_talkidlecolor_preference"
let PREF_APPEARANCE_TALKACTIVECOLOR = "appearance_talkactivecolor_preference"
let PREF_APPEARANCE_SPEAKERSONCOLOR = "appearance_speakersoncolor_preference"
let PREF_APPEARANCE_SPEAKERSMUTEDCOLOR = "appearance_speakersmutedcolor_preference"
let PREF_APPEARANCE_TEXTSIZE = "appearance_textsize_preference"
let PREF_APPEARANCE_COLORSCHEME = "appearance_colorscheme_preference"
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
    static let defaultTalkIdleColor = Color.green
    static let defaultTalkActiveColor = Color.red
    static let defaultSpeakersOnColor = Color.white
    static let defaultSpeakersMutedColor = Color.black
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

    /// Talk button while not transmitting
    @Published var talkIdleColor: Color {
        didSet { Self.save(talkIdleColor, forKey: PREF_APPEARANCE_TALKIDLECOLOR) }
    }

    /// Talk button while transmitting
    @Published var talkActiveColor: Color {
        didSet { Self.save(talkActiveColor, forKey: PREF_APPEARANCE_TALKACTIVECOLOR) }
    }

    /// Speakers button while listening
    @Published var speakersOnColor: Color {
        didSet { Self.save(speakersOnColor, forKey: PREF_APPEARANCE_SPEAKERSONCOLOR) }
    }

    /// Speakers button while everything is muted
    @Published var speakersMutedColor: Color {
        didSet { Self.save(speakersMutedColor, forKey: PREF_APPEARANCE_SPEAKERSMUTEDCOLOR) }
    }

    /// 0 follows the text size of the system, otherwise the position of the
    /// size in DynamicTypeSize counting from 1
    @Published var textSizeIndex: Int {
        didSet { UserDefaults.standard.set(textSizeIndex, forKey: PREF_APPEARANCE_TEXTSIZE) }
    }

    @Published var fontDesign: AppearanceFontDesign {
        didSet { UserDefaults.standard.set(fontDesign.rawValue, forKey: PREF_APPEARANCE_FONTDESIGN) }
    }

    /// 0 follows the system, 1 is always light and 2 always dark
    @Published var colorSchemeIndex: Int {
        didSet { UserDefaults.standard.set(colorSchemeIndex, forKey: PREF_APPEARANCE_COLORSCHEME) }
    }

    var colorScheme: ColorScheme? {
        switch colorSchemeIndex {
        case 1:
            return .light
        case 2:
            return .dark
        default:
            return nil
        }
    }

    private init() {
        let defaults = UserDefaults.standard
        receivedColor = Self.load(forKey: PREF_APPEARANCE_RECEIVEDCOLOR) ?? Self.defaultReceivedColor
        sentColor = Self.load(forKey: PREF_APPEARANCE_SENTCOLOR) ?? Self.defaultSentColor
        interfaceColor = Self.load(forKey: PREF_APPEARANCE_INTERFACECOLOR)
        talkIdleColor = Self.load(forKey: PREF_APPEARANCE_TALKIDLECOLOR) ?? Self.defaultTalkIdleColor
        talkActiveColor = Self.load(forKey: PREF_APPEARANCE_TALKACTIVECOLOR) ?? Self.defaultTalkActiveColor
        speakersOnColor = Self.load(forKey: PREF_APPEARANCE_SPEAKERSONCOLOR) ?? Self.defaultSpeakersOnColor
        speakersMutedColor = Self.load(forKey: PREF_APPEARANCE_SPEAKERSMUTEDCOLOR) ?? Self.defaultSpeakersMutedColor
        textSizeIndex = defaults.integer(forKey: PREF_APPEARANCE_TEXTSIZE)
        fontDesign = AppearanceFontDesign(rawValue: defaults.integer(forKey: PREF_APPEARANCE_FONTDESIGN)) ?? .standard
        colorSchemeIndex = max(0, min(2, defaults.integer(forKey: PREF_APPEARANCE_COLORSCHEME)))
    }

    func restoreDefaults() {
        receivedColor = Self.defaultReceivedColor
        sentColor = Self.defaultSentColor
        interfaceColor = nil
        talkIdleColor = Self.defaultTalkIdleColor
        talkActiveColor = Self.defaultTalkActiveColor
        speakersOnColor = Self.defaultSpeakersOnColor
        speakersMutedColor = Self.defaultSpeakersMutedColor
        textSizeIndex = 0
        fontDesign = .standard
        colorSchemeIndex = 0

        // the defaults follow the light and dark theme, a stored color would not
        let defaults = UserDefaults.standard
        for key in [PREF_APPEARANCE_RECEIVEDCOLOR, PREF_APPEARANCE_SENTCOLOR,
                    PREF_APPEARANCE_TALKIDLECOLOR, PREF_APPEARANCE_TALKACTIVECOLOR,
                    PREF_APPEARANCE_SPEAKERSONCOLOR, PREF_APPEARANCE_SPEAKERSMUTEDCOLOR] {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - Themes

    /// Black and white wherever possible, and saturated colors for the states
    func applyHighContrastTheme() {
        receivedColor = Self.color(hex: "000000")
        sentColor = Self.color(hex: "FFFFFF")
        interfaceColor = nil
        talkIdleColor = Self.color(hex: "006400")
        talkActiveColor = Self.color(hex: "B00000")
        speakersOnColor = Self.color(hex: "FFFFFF")
        speakersMutedColor = Self.color(hex: "000000")
    }

    /// Dark whatever the system says, with dim colors that do not glare at night
    func applyPureDarkTheme() {
        colorSchemeIndex = 2
        receivedColor = Self.color(hex: "1C1C1E")
        sentColor = Self.color(hex: "0A3D62")
        interfaceColor = Self.color(hex: "0A84FF")
        talkIdleColor = Self.color(hex: "14532D")
        talkActiveColor = Self.color(hex: "7F1D1D")
        speakersOnColor = Self.color(hex: "2C2C2E")
        speakersMutedColor = Self.color(hex: "000000")
    }

    // MARK: - Sharing the appearance

    private static let exportFormat = "TeamTalk appearance"

    /// The appearance as a small file to hand to someone else
    func exportFile() -> URL? {
        let settings: [String: Any] = [
            "format": Self.exportFormat,
            "version": 1,
            "receivedColor": Self.hex(of: receivedColor),
            "sentColor": Self.hex(of: sentColor),
            "interfaceColor": interfaceColor.map { Self.hex(of: $0) } ?? "",
            "talkIdleColor": Self.hex(of: talkIdleColor),
            "talkActiveColor": Self.hex(of: talkActiveColor),
            "speakersOnColor": Self.hex(of: speakersOnColor),
            "speakersMutedColor": Self.hex(of: speakersMutedColor),
            "textSize": textSizeIndex,
            "font": fontDesign.rawValue,
            "colorScheme": colorSchemeIndex
        ]

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TeamTalk appearance.json")
        guard let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]),
              (try? data.write(to: url, options: .atomic)) != nil else {
            return nil
        }
        return url
    }

    /// False if the file is not an appearance exported by this app
    func importFile(_ url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let settings = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              settings["format"] as? String == Self.exportFormat else {
            return false
        }

        func color(_ key: String, default fallback: Color) -> Color {
            guard let hex = settings[key] as? String, hex.count == 6, UInt32(hex, radix: 16) != nil else {
                return fallback
            }
            return Self.color(hex: hex)
        }

        receivedColor = color("receivedColor", default: Self.defaultReceivedColor)
        sentColor = color("sentColor", default: Self.defaultSentColor)
        if let hex = settings["interfaceColor"] as? String, hex.count == 6, UInt32(hex, radix: 16) != nil {
            interfaceColor = Self.color(hex: hex)
        } else {
            interfaceColor = nil
        }
        talkIdleColor = color("talkIdleColor", default: Self.defaultTalkIdleColor)
        talkActiveColor = color("talkActiveColor", default: Self.defaultTalkActiveColor)
        speakersOnColor = color("speakersOnColor", default: Self.defaultSpeakersOnColor)
        speakersMutedColor = color("speakersMutedColor", default: Self.defaultSpeakersMutedColor)
        textSizeIndex = max(0, min(DynamicTypeSize.allCases.count, settings["textSize"] as? Int ?? 0))
        fontDesign = AppearanceFontDesign(rawValue: settings["font"] as? Int ?? 0) ?? .standard
        colorSchemeIndex = max(0, min(2, settings["colorScheme"] as? Int ?? 0))
        return true
    }

    func swapTalkColors() {
        let idle = talkIdleColor
        talkIdleColor = talkActiveColor
        talkActiveColor = idle
    }

    func swapSpeakersColors() {
        let listening = speakersOnColor
        speakersOnColor = speakersMutedColor
        speakersMutedColor = listening
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

    /// "RRGGBB", the form in which colors are stored and handed to the Live Activity
    static func hex(of color: Color) -> String {
        let rgb = components(of: color)
        return String(format: "%02X%02X%02X",
                      Int((rgb.red * 255).rounded()),
                      Int((rgb.green * 255).rounded()),
                      Int((rgb.blue * 255).rounded()))
    }

    private static func save(_ color: Color, forKey key: String) {
        UserDefaults.standard.set(hex(of: color), forKey: key)
    }

    private static func load(forKey key: String) -> Color? {
        guard let hex = UserDefaults.standard.string(forKey: key), hex.count == 6,
              UInt32(hex, radix: 16) != nil else {
            return nil
        }
        return color(hex: hex)
    }

    /// From "RRGGBB". Black if it is not one.
    static func color(hex: String) -> Color {
        let value = UInt32(hex, radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xFF) / 255,
                     green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }
}
