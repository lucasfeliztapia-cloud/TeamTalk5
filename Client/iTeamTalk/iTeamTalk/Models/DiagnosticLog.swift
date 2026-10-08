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
import TeamTalkKit
import UIKit

/// What the app has been doing, kept in memory so it can be read and shared
/// from the device when something goes wrong.
final class DiagnosticLog: ObservableObject {

    static let shared = DiagnosticLog()

    @Published private(set) var lines = [String]()

    private let maxLines = 2000
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    func add(_ message: String) {
        let line = formatter.string(from: Date()) + " " + message
        print(line)
        if Thread.isMainThread {
            append(line)
        } else {
            DispatchQueue.main.async {
                self.append(line)
            }
        }
    }

    func clear() {
        lines.removeAll()
    }

    private func append(_ line: String) {
        lines.append(line)
        if lines.count > maxLines {
            lines.removeFirst(lines.count - maxLines)
        }
    }

    /// App, system and device, which is the first thing asked about a failure.
    var header: String {
        var system = utsname()
        uname(&system)
        let machine = withUnsafeBytes(of: &system.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }

        return [
            "\(AppInfo.getAppName()) \(AppInfo.getAppVersionLong())",
            "Library \(TeamTalkClient.shared.version)",
            "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion), \(machine)",
            "Locale \(Locale.current.identifier), VoiceOver \(UIAccessibility.isVoiceOverRunning ? "on" : "off")"
        ].joined(separator: "\n")
    }

    /// The log written to a text file, for the share sheet.
    func exportFile() -> URL? {
        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyy-MM-dd HH.mm.ss"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TeamTalk diagnostics \(stamp.string(from: Date())).txt")
        let text = header + "\n\n" + lines.joined(separator: "\n") + "\n"
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

func logDiagnostic(_ message: String) {
    DiagnosticLog.shared.add(message)
}

/// Name of the events worth reading in the log.
func clientEventName(_ event: ClientEvent) -> String {
    switch event {
    case CLIENTEVENT_CON_SUCCESS: return "CON_SUCCESS"
    case CLIENTEVENT_CON_FAILED: return "CON_FAILED"
    case CLIENTEVENT_CON_LOST: return "CON_LOST"
    case CLIENTEVENT_CMD_PROCESSING: return "CMD_PROCESSING"
    case CLIENTEVENT_CMD_ERROR: return "CMD_ERROR"
    case CLIENTEVENT_CMD_SUCCESS: return "CMD_SUCCESS"
    case CLIENTEVENT_CMD_MYSELF_LOGGEDIN: return "MYSELF_LOGGEDIN"
    case CLIENTEVENT_CMD_MYSELF_LOGGEDOUT: return "MYSELF_LOGGEDOUT"
    case CLIENTEVENT_CMD_MYSELF_KICKED: return "MYSELF_KICKED"
    case CLIENTEVENT_CMD_USER_LOGGEDIN: return "USER_LOGGEDIN"
    case CLIENTEVENT_CMD_USER_LOGGEDOUT: return "USER_LOGGEDOUT"
    case CLIENTEVENT_CMD_USER_UPDATE: return "USER_UPDATE"
    case CLIENTEVENT_CMD_USER_JOINED: return "USER_JOINED"
    case CLIENTEVENT_CMD_USER_LEFT: return "USER_LEFT"
    case CLIENTEVENT_CMD_USER_TEXTMSG: return "USER_TEXTMSG"
    case CLIENTEVENT_CMD_CHANNEL_NEW: return "CHANNEL_NEW"
    case CLIENTEVENT_CMD_CHANNEL_UPDATE: return "CHANNEL_UPDATE"
    case CLIENTEVENT_CMD_CHANNEL_REMOVE: return "CHANNEL_REMOVE"
    case CLIENTEVENT_CMD_SERVER_UPDATE: return "SERVER_UPDATE"
    case CLIENTEVENT_CMD_FILE_NEW: return "FILE_NEW"
    case CLIENTEVENT_CMD_FILE_REMOVE: return "FILE_REMOVE"
    case CLIENTEVENT_USER_STATECHANGE: return "USER_STATECHANGE"
    case CLIENTEVENT_VOICE_ACTIVATION: return "VOICE_ACTIVATION"
    case CLIENTEVENT_INTERNAL_ERROR: return "INTERNAL_ERROR"
    case CLIENTEVENT_FILETRANSFER: return "FILETRANSFER"
    case CLIENTEVENT_STREAM_MEDIAFILE: return "STREAM_MEDIAFILE"
    case CLIENTEVENT_LOCAL_MEDIAFILE: return "LOCAL_MEDIAFILE"
    default: return "EVENT_\(event.rawValue)"
    }
}
