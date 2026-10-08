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

/// A file another app handed over with "Open in TeamTalk". It waits here
/// until there is a channel to upload or stream it to.
final class IncomingFileModel: ObservableObject {

    static let shared = IncomingFileModel()

    @Published private(set) var pending: SharedFile?

    private var folder: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Incoming", isDirectory: true)
    }

    private init() {}

    /// Keeps a copy owned by the app. False if the file could not be read.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        // a file opened in place is only readable while its security scope is held
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // one file at a time, the newest replaces the one before
        let files = FileManager.default
        try? files.removeItem(at: folder)

        let copy = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            try files.copyItem(at: url, to: copy)
        } catch {
            logDiagnostic("Incoming file: FAILED to copy \(url.lastPathComponent), \(error)")
            pending = nil
            return false
        }

        // what iOS left in the inbox of the app is not needed any more
        if url.path.contains("/Documents/Inbox/") {
            try? files.removeItem(at: url)
        }

        logDiagnostic("Incoming file: \(url.lastPathComponent)")
        pending = SharedFile(url: copy)
        return true
    }

    /// The file has been sent, or the user does not want it
    func clear() {
        pending = nil
    }
}
