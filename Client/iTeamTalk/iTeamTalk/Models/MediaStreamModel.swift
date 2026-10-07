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
import SwiftUI
import TeamTalkKit

let DEFAULT_MEDIAFILE_VIDEO_BITRATE = INT32(256)

final class MediaStreamModel: ObservableObject {

    enum State {
        case idle
        case playing
        case paused
    }

    @Published var fileName = ""
    @Published var durationMSec: Double = 0
    @Published var positionMSec: Double = 0
    @Published var hasVideo = false
    @Published var sendVideo = true
    @Published var state = State.idle
    @Published var isPreparing = false
    @Published var inChannel = false
    @Published var canStreamAudio = false
    @Published var canStreamVideo = false
    @Published var errorMessage: String?

    private var fileURL: URL?
    private var userRights: UInt32 = 0
    // events of a stream that has already been stopped are still queued
    private var active = false
    private var pendingSeek: DispatchWorkItem?
    private var ignoreProgressUntil = Date.distantPast

    private let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("streaming", isDirectory: true)

    init() {
        // the copy of the last streamed file
        try? FileManager.default.removeItem(at: directory)
    }

    var hasFile: Bool {
        fileURL != nil
    }

    var isStreaming: Bool {
        state != .idle
    }

    var canStart: Bool {
        hasFile && inChannel && canStreamAudio && !isPreparing
    }

    var positionText: String {
        Self.clockText(positionMSec)
    }

    var durationText: String {
        Self.clockText(durationMSec)
    }

    var spokenPositionText: String {
        String(format: String(localized: "%@ of %@", comment: "media stream"),
               Self.spokenText(positionMSec), Self.spokenText(durationMSec))
    }

    var statusText: String {
        if isPreparing {
            return String(localized: "Preparing file", comment: "media stream")
        }
        switch state {
        case .playing:
            return String(localized: "Streaming", comment: "media stream")
        case .paused:
            return String(localized: "Paused", comment: "media stream")
        case .idle:
            if !inChannel {
                return String(localized: "Join a channel to stream a media file", comment: "media stream")
            }
            if !canStreamAudio {
                return String(localized: "You are not allowed to stream media files on this server", comment: "media stream")
            }
            return String(localized: "Not streaming", comment: "media stream")
        }
    }

    // MARK: - File

    func selectFile(_ url: URL) {
        stop()
        isPreparing = true

        // The picked file is only readable while its security scope is held and
        // the stream outlives this call, so stream a copy owned by the app.
        let directory = self.directory
        DispatchQueue.global(qos: .userInitiated).async {
            let scoped = url.startAccessingSecurityScopedResource()
            let copy = directory.appendingPathComponent(url.lastPathComponent)
            var failure: String?
            do {
                try? FileManager.default.removeItem(at: directory)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: copy)
            } catch {
                failure = error.localizedDescription
            }
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
            let info = failure == nil ? TeamTalkClient.mediaFileInfo(path: copy.path) : nil

            DispatchQueue.main.async {
                self.fileSelected(copy, info: info, failure: failure)
            }
        }
    }

    private func fileSelected(_ copy: URL, info: MediaFileInfo?, failure: String?) {
        isPreparing = false

        guard let info, info.audioFmt.nSampleRate > 0 || info.videoFmt.nWidth > 0 else {
            try? FileManager.default.removeItem(at: directory)
            fileURL = nil
            fileName = ""
            durationMSec = 0
            positionMSec = 0
            hasVideo = false
            errorMessage = failure ?? String(localized: "This file cannot be streamed", comment: "media stream")
            return
        }

        fileURL = copy
        fileName = copy.lastPathComponent
        durationMSec = Double(info.uDurationMSec)
        positionMSec = 0
        hasVideo = info.videoFmt.nWidth > 0
        announceForAccessibility(
            String(format: String(localized: "%@ ready, %@", comment: "media stream"),
                   fileName, Self.spokenText(durationMSec))
        )
    }

    // MARK: - Actions

    func start() {
        guard let fileURL, canStart, state == .idle else { return }

        // the offset has to be inside the file
        let offset = min(positionMSec, max(0, durationMSec - 1000))
        if TeamTalkClient.shared.startStreamingMediaFile(
            path: fileURL.path,
            offsetMSec: UInt32(max(0, offset)),
            paused: false,
            videoCodec: videoCodec
        ) {
            positionMSec = max(0, offset)
            active = true
            state = .playing
        } else {
            errorMessage = String(localized: "Failed to stream media file", comment: "media stream")
        }
    }

    func togglePause() {
        guard isStreaming else { return }

        let pause = state == .playing
        if TeamTalkClient.shared.updateStreamingMediaFile(
            offsetMSec: TeamTalkClient.mediaPlaybackOffsetIgnore,
            paused: pause,
            videoCodec: videoCodec
        ) {
            state = pause ? .paused : .playing
        }
    }

    func stop() {
        pendingSeek?.cancel()
        pendingSeek = nil
        guard isStreaming else { return }

        TeamTalkClient.shared.stopStreamingMediaFile()
        active = false
        state = .idle
    }

    func skip(seconds: Double) {
        setPosition(positionMSec + seconds * 1000)
    }

    /// Position chosen by the user. The slider reports every step of a drag, so
    /// the stream is only moved once the value has settled.
    func setPosition(_ msec: Double) {
        positionMSec = min(max(0, msec), max(0, durationMSec - 1000))

        pendingSeek?.cancel()
        pendingSeek = nil
        guard isStreaming else { return }

        let seek = DispatchWorkItem { [weak self] in
            self?.seek()
        }
        pendingSeek = seek
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: seek)
    }

    private func seek() {
        pendingSeek = nil
        guard isStreaming else { return }

        TeamTalkClient.shared.updateStreamingMediaFile(
            offsetMSec: UInt32(positionMSec),
            paused: state == .paused,
            videoCodec: videoCodec
        )
        // progress reported before the seek took effect would move the slider back
        ignoreProgressUntil = Date().addingTimeInterval(1.0)
    }

    private var videoCodec: VideoCodec {
        if hasVideo && sendVideo && canStreamVideo {
            return TeamTalkVideoCodec.makeWebMVP8Codec(targetBitrate: DEFAULT_MEDIAFILE_VIDEO_BITRATE)
        }
        return TeamTalkVideoCodec.makeNoCodec()
    }

    private func updateProgress(_ info: MediaFileInfo) {
        guard pendingSeek == nil, Date() >= ignoreProgressUntil else { return }
        positionMSec = Double(info.uElapsedMSec)
    }

    private func updateRights() {
        canStreamAudio = (userRights & USERRIGHT_TRANSMIT_MEDIAFILE_AUDIO.rawValue) != 0
        canStreamVideo = (userRights & USERRIGHT_TRANSMIT_MEDIAFILE_VIDEO.rawValue) != 0
    }

    // MARK: - Formatting

    static func clockText(_ msec: Double) -> String {
        let total = Int(msec / 1000)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// "1:05" is read by VoiceOver as a time of day, so durations are spelled out.
    static func spokenText(_ msec: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: TimeInterval(Int(msec / 1000))) ?? clockText(msec)
    }
}

// MARK: - TeamTalkEvent

extension MediaStreamModel: TeamTalkEvent {
    func handleTTMessage(_ m: TTMessage) {
        switch m.nClientEvent {

        case CLIENTEVENT_CON_LOST, CLIENTEVENT_CMD_MYSELF_LOGGEDOUT:
            stop()
            state = .idle
            inChannel = false

        case CLIENTEVENT_CMD_MYSELF_LOGGEDIN:
            let account = TeamTalkMessagePayload.userAccount(from: m)
            userRights = (account.uUserType & USERTYPE_ADMIN.rawValue) != 0 ? 0xFFFFFFFF : account.uUserRights
            updateRights()

        case CLIENTEVENT_CMD_USER_JOINED:
            if TeamTalkMessagePayload.user(from: m).nUserID == TeamTalkClient.shared.myUserID {
                inChannel = true
            }

        case CLIENTEVENT_CMD_USER_LEFT:
            if TeamTalkMessagePayload.user(from: m).nUserID == TeamTalkClient.shared.myUserID {
                stop()
                inChannel = false
            }

        case CLIENTEVENT_STREAM_MEDIAFILE:
            guard active else { break }
            let info = TeamTalkMessagePayload.mediaFileInfo(from: m)
            switch info.nStatus {
            case MFS_STARTED:
                state = .playing
                announceForAccessibility(String(localized: "Streaming started", comment: "media stream"))
            case MFS_PLAYING:
                state = .playing
                updateProgress(info)
            case MFS_PAUSED:
                state = .paused
                updateProgress(info)
            case MFS_FINISHED:
                stop()
                positionMSec = 0
                announceForAccessibility(String(localized: "Streaming finished", comment: "media stream"))
            case MFS_ERROR:
                stop()
                errorMessage = String(localized: "Error while streaming media file", comment: "media stream")
            case MFS_ABORTED:
                stop()
            default:
                break
            }

        default:
            break
        }
    }
}
