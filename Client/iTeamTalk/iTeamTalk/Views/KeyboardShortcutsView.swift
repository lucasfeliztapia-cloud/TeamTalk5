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

/// What an external keyboard can do while connected to a server
enum KeyboardAction: String, CaseIterable, Identifiable {
    case transmit
    case speakers
    case streamPause
    case streamStop

    var id: String {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .transmit:
            return "Toggle Transmission"
        case .speakers:
            return "Mute or Unmute Speakers"
        case .streamPause:
            return "Pause or Resume Streaming"
        case .streamStop:
            return "Stop Streaming"
        }
    }

    /// Index into `KeyboardShortcutsModel.keys` and into `modifiers`
    var defaultShortcut: (key: Int, modifier: Int) {
        switch self {
        case .transmit:
            return (1, 0)   // Space
        case .speakers:
            return (15, 1)  // Command M
        case .streamPause:
            return (18, 1)  // Command P
        case .streamStop:
            return (21, 1)  // Command S
        }
    }
}

final class KeyboardShortcutsModel: ObservableObject {

    static let shared = KeyboardShortcutsModel()

    /// "None" first, then space and return, the letters and the digits
    static let keys: [(title: String, key: KeyEquivalent?)] = {
        var keys: [(title: String, key: KeyEquivalent?)] = [
            (String(localized: "None", comment: "keyboard shortcuts"), nil),
            (String(localized: "Space", comment: "keyboard shortcuts"), .space),
            (String(localized: "Return", comment: "keyboard shortcuts"), .return)
        ]
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" {
            keys.append((String(letter), KeyEquivalent(Character(letter.lowercased()))))
        }
        return keys
    }()

    static let modifiers: [(title: String, modifiers: EventModifiers)] = [
        (String(localized: "No Modifier", comment: "keyboard shortcuts"), []),
        (String(localized: "Command", comment: "keyboard shortcuts"), .command),
        (String(localized: "Option", comment: "keyboard shortcuts"), .option),
        (String(localized: "Control", comment: "keyboard shortcuts"), .control),
        (String(localized: "Shift", comment: "keyboard shortcuts"), .shift)
    ]

    @Published private var revision = 0

    private init() {}

    private func preference(_ action: KeyboardAction, _ part: String) -> String {
        "keyboard_\(action.rawValue)_\(part)_preference"
    }

    func keyIndex(for action: KeyboardAction) -> Int {
        let defaults = UserDefaults.standard
        let name = preference(action, "key")
        let index = defaults.object(forKey: name) == nil ? action.defaultShortcut.key : defaults.integer(forKey: name)
        return Self.keys.indices.contains(index) ? index : 0
    }

    func modifierIndex(for action: KeyboardAction) -> Int {
        let defaults = UserDefaults.standard
        let name = preference(action, "modifier")
        let index = defaults.object(forKey: name) == nil ? action.defaultShortcut.modifier : defaults.integer(forKey: name)
        return Self.modifiers.indices.contains(index) ? index : 0
    }

    func setKeyIndex(_ index: Int, for action: KeyboardAction) {
        UserDefaults.standard.set(index, forKey: preference(action, "key"))
        revision += 1
    }

    func setModifierIndex(_ index: Int, for action: KeyboardAction) {
        UserDefaults.standard.set(index, forKey: preference(action, "modifier"))
        revision += 1
    }

    func restoreDefaults() {
        for action in KeyboardAction.allCases {
            UserDefaults.standard.removeObject(forKey: preference(action, "key"))
            UserDefaults.standard.removeObject(forKey: preference(action, "modifier"))
        }
        revision += 1
    }

    /// nil when the action has no key
    func shortcut(for action: KeyboardAction) -> KeyboardShortcut? {
        guard let key = Self.keys[keyIndex(for: action)].key else { return nil }
        return KeyboardShortcut(key, modifiers: Self.modifiers[modifierIndex(for: action)].modifiers)
    }

    func summary(for action: KeyboardAction) -> String {
        let key = Self.keys[keyIndex(for: action)]
        guard key.key != nil else { return key.title }
        let modifier = modifierIndex(for: action)
        return modifier == 0 ? key.title : Self.modifiers[modifier].title + " " + key.title
    }
}

/// Invisible buttons that carry the shortcuts. They sit behind the connected
/// screens so the keys work whichever tab is in front.
struct KeyboardShortcutButtons: View {
    @ObservedObject private var shortcuts = KeyboardShortcutsModel.shared
    let perform: (KeyboardAction) -> Void

    var body: some View {
        ZStack {
            ForEach(KeyboardAction.allCases) { action in
                if let shortcut = shortcuts.shortcut(for: action) {
                    Button("") {
                        perform(action)
                    }
                    .keyboardShortcut(shortcut)
                }
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}

struct KeyboardShortcutsView: View {
    @ObservedObject private var shortcuts = KeyboardShortcutsModel.shared

    var body: some View {
        Form {
            ForEach(KeyboardAction.allCases) { action in
                Section {
                    Picker("Key", selection: Binding(
                        get: { shortcuts.keyIndex(for: action) },
                        set: { shortcuts.setKeyIndex($0, for: action) }
                    )) {
                        ForEach(KeyboardShortcutsModel.keys.indices, id: \.self) { index in
                            Text(verbatim: KeyboardShortcutsModel.keys[index].title).tag(index)
                        }
                    }
                    Picker("Modifier", selection: Binding(
                        get: { shortcuts.modifierIndex(for: action) },
                        set: { shortcuts.setModifierIndex($0, for: action) }
                    )) {
                        ForEach(KeyboardShortcutsModel.modifiers.indices, id: \.self) { index in
                            Text(verbatim: KeyboardShortcutsModel.modifiers[index].title).tag(index)
                        }
                    }
                } header: {
                    Text(action.title)
                } footer: {
                    Text(verbatim: shortcuts.summary(for: action))
                }
            }

            Section {
                Button(action: shortcuts.restoreDefaults) {
                    Text("Restore Default Shortcuts")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            } footer: {
                Text("Shortcuts work with an external keyboard while connected to a server. A key without a modifier does nothing while you are typing a message.")
            }
        }
        .navigationTitle("Keyboard Shortcuts")
    }
}
