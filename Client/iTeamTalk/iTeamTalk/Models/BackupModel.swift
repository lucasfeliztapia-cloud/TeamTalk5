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

import Foundation

/// Every setting of the app and its list of servers in one file, to bring
/// them back after reinstalling. The file holds the passwords of the servers.
enum SettingsBackup {

    private static let marker = "TeamTalkBackupVersion"

    static func exportFile() -> URL? {
        guard let domain = Bundle.main.bundleIdentifier,
              var settings = UserDefaults.standard.persistentDomain(forName: domain) else {
            return nil
        }

        // the playlist points to files that are not part of the backup
        settings.removeValue(forKey: PREF_STREAM_PLAYLIST)
        settings[marker] = 1

        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TeamTalk backup \(stamp.string(from: Date())).ttbackup")

        do {
            let data = try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            logDiagnostic("Backup: FAILED to export, \(error)")
            return nil
        }
    }

    /// False if the file is not a backup made by this app
    static func importFile(_ url: URL) -> Bool {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let settings = plist as? [String: Any],
              settings[marker] != nil else {
            logDiagnostic("Backup: the chosen file is not a backup")
            return false
        }

        for (key, value) in settings where key != marker {
            UserDefaults.standard.set(value, forKey: key)
        }
        logDiagnostic("Backup: restored \(settings.count - 1) settings")
        return true
    }
}
