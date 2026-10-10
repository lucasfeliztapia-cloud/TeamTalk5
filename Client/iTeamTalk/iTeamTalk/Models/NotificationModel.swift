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

import TeamTalkKit
import UIKit
import UserNotifications

let PREF_NOTIFY_BACKGROUND = "notifications_background_preference"
let PREF_NOTIFY_USERMSG = "notifications_usermsg_preference"
let PREF_NOTIFY_CHANMSG = "notifications_chanmsg_preference"
let PREF_NOTIFY_BROADCAST = "notifications_broadcast_preference"

/// Notifications of the system for the text messages that arrive while the
/// app is not in front. Off until the user turns them on.
enum TextMessageNotifications {

    static func isOn(_ key: String, default value: Bool) -> Bool {
        let settings = UserDefaults.standard
        return settings.object(forKey: key) == nil ? value : settings.bool(forKey: key)
    }

    /// Asks iOS for its permission. False when the user has refused it.
    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    static func post(_ msgtype: TextMsgType, message: MyTextMessage) {
        guard isOn(PREF_NOTIFY_BACKGROUND, default: false),
              UIApplication.shared.applicationState != .active,
              message.msgtype != .PRIV_IM_MYSELF, message.msgtype != .CHAN_IM_MYSELF else { return }

        let kind: String
        switch msgtype {
        case MSGTYPE_USER:
            guard isOn(PREF_NOTIFY_USERMSG, default: true) else { return }
            kind = String(localized: "Private Message", comment: "notification")
        case MSGTYPE_CHANNEL:
            guard isOn(PREF_NOTIFY_CHANMSG, default: false) else { return }
            kind = String(localized: "Channel message", comment: "notification")
        case MSGTYPE_BROADCAST:
            guard isOn(PREF_NOTIFY_BROADCAST, default: true) else { return }
            kind = String(localized: "Broadcast Message", comment: "notification")
        default:
            return
        }

        let content = UNMutableNotificationContent()
        content.title = message.nickname
        content.subtitle = kind
        content.body = message.message
        // no sound of its own: the app already plays the one of the event
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            guard let error else { return }
            DispatchQueue.main.async {
                logDiagnostic("Notification failed: \(error.localizedDescription)")
            }
        }
    }
}
