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

import ActivityKit
import Foundation

struct LiveActivityStatus: Equatable {
    var serverName: String
    var statusText: String
    var isConnected: Bool
    var isTransmitting: Bool
    var isDeafened: Bool
    var talkColor: String
    var speakersColor: String
}

/// The Live Activity of the current connection. Needs iOS 17 for its buttons;
/// on older systems these calls do nothing.
enum LiveActivityController {

    static func update(_ status: LiveActivityStatus) {
        if #available(iOS 17.0, *) {
            LiveActivityManager.shared.update(status)
        }
    }

    static func end() {
        if #available(iOS 17.0, *) {
            LiveActivityManager.shared.end()
        }
    }
}

@available(iOS 17.0, *)
private final class LiveActivityManager {

    static let shared = LiveActivityManager()

    private var activity: Activity<TeamTalkActivityAttributes>?
    private var status: LiveActivityStatus?
    // updates are sent one after the other so an older one never lands last
    private var pending: Task<Void, Never>?

    func update(_ status: LiveActivityStatus) {
        guard status != self.status else { return }

        if let activity, activity.attributes.serverName == status.serverName {
            self.status = status
            send(to: activity, state: contentState(status))
        } else if status.isConnected {
            start(status)
        }
    }

    func end() {
        // also the ones left by a previous run of the app
        let activities = Activity<TeamTalkActivityAttributes>.activities
        activity = nil
        status = nil

        let previous = pending
        pending = Task {
            await previous?.value
            for activity in activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func start(_ status: LiveActivityStatus) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        end()

        let attributes = TeamTalkActivityAttributes(
            serverName: status.serverName,
            transmitLabel: String(localized: "Transmission", comment: "live activity"),
            transmitOnText: String(localized: "Transmitting", comment: "live activity"),
            transmitOffText: String(localized: "Not transmitting", comment: "live activity"),
            speakersLabel: String(localized: "Speakers", comment: "channel list"),
            speakersOnText: String(localized: "On", comment: "channel list"),
            speakersMutedText: String(localized: "Muted", comment: "channel list")
        )

        do {
            // can only be requested while the app is in the foreground
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: contentState(status), staleDate: nil),
                pushType: nil
            )
            self.status = status
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    private func send(to activity: Activity<TeamTalkActivityAttributes>,
                      state: TeamTalkActivityAttributes.ContentState) {
        let previous = pending
        pending = Task {
            await previous?.value
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    private func contentState(_ status: LiveActivityStatus) -> TeamTalkActivityAttributes.ContentState {
        TeamTalkActivityAttributes.ContentState(
            statusText: status.statusText,
            isConnected: status.isConnected,
            isTransmitting: status.isTransmitting,
            isDeafened: status.isDeafened,
            talkColor: status.talkColor,
            speakersColor: status.speakersColor
        )
    }
}
