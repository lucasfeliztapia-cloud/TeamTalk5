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

/// Notes of what the app is doing, for the console of the system. They were
/// also kept in a log the user could read and share from Preferences; that
/// screen is gone and nothing is stored.
func logDiagnostic(_ message: String) {
    print("[TeamTalk] \(message)")
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
