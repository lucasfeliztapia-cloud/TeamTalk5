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
import AppIntents
import SwiftUI
import WidgetKit

@main
struct TeamTalkLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TeamTalkLiveActivity()
    }
}

struct TeamTalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TeamTalkActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 10) {
                ActivityHeader(attributes: context.attributes, state: context.state)
                ActivityControls(attributes: context.attributes, state: context.state)
                if !context.state.streamName.isEmpty {
                    StreamControls(attributes: context.attributes, state: context.state)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ActivityHeader(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        ActivityControls(attributes: context.attributes, state: context.state)
                        if !context.state.streamName.isEmpty {
                            StreamControls(attributes: context.attributes, state: context.state)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "person.wave.2.fill")
                    .accessibilityLabel(context.attributes.serverName)
            } compactTrailing: {
                TransmissionIcon(attributes: context.attributes, state: context.state)
            } minimal: {
                TransmissionIcon(attributes: context.attributes, state: context.state)
            }
        }
    }
}

private struct ActivityHeader: View {
    let attributes: TeamTalkActivityAttributes
    let state: TeamTalkActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: state.isConnected ? "person.wave.2.fill" : "wifi.slash")
                .font(.title3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.serverName)
                    .font(.headline)
                    .lineLimit(1)
                Text(state.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ActivityControls: View {
    let attributes: TeamTalkActivityAttributes
    let state: TeamTalkActivityAttributes.ContentState

    var body: some View {
        let talk = ActivityColor(hex: state.talkColor, fallback: state.isTransmitting ? .red : .green)
        let speakers = ActivityColor(hex: state.speakersColor, fallback: state.isDeafened ? .black : .white)

        HStack(spacing: 12) {
            Button(intent: ToggleTransmissionIntent()) {
                Label(attributes.transmitLabel, systemImage: state.isTransmitting ? "mic.fill" : "mic.slash.fill")
                    .lineLimit(1)
                    .foregroundStyle(talk.text)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(talk.color)
            .accessibilityLabel(attributes.transmitLabel)
            .accessibilityValue(state.isTransmitting ? attributes.transmitOnText : attributes.transmitOffText)

            // the same colors as the button in the app
            Button(intent: ToggleDeafenIntent()) {
                Image(systemName: state.isDeafened ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(speakers.text)
                    .frame(width: 64, height: 34)
                    .background(speakers.color, in: Capsule())
                    .overlay(Capsule().stroke(Color.gray, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(attributes.speakersLabel)
            .accessibilityValue(state.isDeafened ? attributes.speakersMutedText : attributes.speakersOnText)
        }
        .disabled(!state.isConnected)
    }
}

/// The media file being streamed, with pause and stop
private struct StreamControls: View {
    let attributes: TeamTalkActivityAttributes
    let state: TeamTalkActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .accessibilityHidden(true)
            Text(state.streamName)
                .font(.subheadline)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(intent: ToggleStreamPauseIntent()) {
                Image(systemName: state.isStreamPaused ? "play.fill" : "pause.fill")
                    .frame(width: 44, height: 30)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(state.isStreamPaused ? attributes.streamResumeLabel : attributes.streamPauseLabel)
            Button(intent: StopStreamIntent()) {
                Image(systemName: "stop.fill")
                    .frame(width: 44, height: 30)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(attributes.streamStopLabel)
        }
    }
}

private struct TransmissionIcon: View {
    let attributes: TeamTalkActivityAttributes
    let state: TeamTalkActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.isTransmitting ? "mic.fill" : "mic.slash.fill")
            .foregroundStyle(ActivityColor(hex: state.talkColor, fallback: state.isTransmitting ? .red : .green).color)
            .accessibilityLabel(attributes.transmitLabel)
            .accessibilityValue(state.isTransmitting ? attributes.transmitOnText : attributes.transmitOffText)
    }
}
