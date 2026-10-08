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

let PREF_STREAM_PLAYLIST = "stream_playlist_preference"
let PREF_STREAM_VOLUME = "stream_volume_preference"
let PREF_STREAM_REPEAT = "stream_repeat_preference"

/// A file of the playlist, or a web address streamed as it arrives
struct StreamItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    /// File name inside the folder of the item, or the web address
    var location: String
    var isWeb: Bool
    var durationMSec: Double
    var hasVideo: Bool

    /// A web radio has no end, and so no position to move to
    var isLive: Bool {
        isWeb && durationMSec <= 0
    }
}

enum StreamRepeat: Int, CaseIterable, Identifiable {
    case off = 0
    case all
    case one

    var id: Int {
        rawValue
    }

    var title: LocalizedStringKey {
        switch self {
        case .off:
            return "Off"
        case .all:
            return "Whole List"
        case .one:
            return "Current File"
        }
    }
}

final class MediaStreamModel: ObservableObject {

    enum State {
        case idle
        case playing
        case paused
    }

    @Published var items = [StreamItem]()
    @Published var currentID: UUID?
    @Published var positionMSec: Double = 0
    @Published var sendVideo = true
    @Published var state = State.idle
    @Published var isPreparing = false
    @Published var isPreviewing = false
    @Published var inChannel = false
    @Published var canStreamAudio = false
    @Published var canStreamVideo = false
    @Published var errorMessage: String?

    /// 100 leaves the file as it is
    @Published var volumePercent: Double {
        didSet {
            UserDefaults.standard.set(volumePercent, forKey: PREF_STREAM_VOLUME)
            applyVolume()
        }
    }

    @Published var repeatMode: StreamRepeat {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: PREF_STREAM_REPEAT) }
    }

    private var userRights: UInt32 = 0
    // events of a stream that has already been stopped are still queued
    private var active = false
    private var previewSession: INT32 = 0
    private var pendingSeek: DispatchWorkItem?
    private var ignoreProgressUntil = Date.distantPast

    /// Not the temporary folder: the playlist is kept between sessions
    private let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Streaming", isDirectory: true)
    }()

    init() {
        let defaults = UserDefaults.standard
        volumePercent = defaults.object(forKey: PREF_STREAM_VOLUME) == nil ? 100 : defaults.double(forKey: PREF_STREAM_VOLUME)
        repeatMode = StreamRepeat(rawValue: defaults.integer(forKey: PREF_STREAM_REPEAT)) ?? .off

        if let data = defaults.data(forKey: PREF_STREAM_PLAYLIST),
           let stored = try? JSONDecoder().decode([StreamItem].self, from: data) {
            // a file that is gone, for instance after restoring a backup
            items = stored.filter { $0.isWeb || FileManager.default.fileExists(atPath: path(for: $0)) }
        }
        currentID = items.first?.id
    }

    // MARK: - Current item

    var current: StreamItem? {
        items.first { $0.id == currentID }
    }

    var hasFile: Bool {
        current != nil
    }

    var fileName: String {
        current?.name ?? ""
    }

    var durationMSec: Double {
        current?.durationMSec ?? 0
    }

    var hasVideo: Bool {
        current?.hasVideo ?? false
    }

    var isLive: Bool {
        current?.isLive ?? false
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
        isLive ? String(localized: "Live", comment: "media stream") : Self.clockText(durationMSec)
    }

    var spokenPositionText: String {
        String(format: String(localized: "%@ of %@", comment: "media stream"),
               Self.spokenText(positionMSec), Self.spokenText(durationMSec))
    }

    var volumeText: String {
        "\(Int(volumePercent.rounded())) %"
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

    func detail(for item: StreamItem) -> String {
        if item.isLive {
            return String(localized: "Web address, live", comment: "media stream")
        }
        let duration = Self.clockText(item.durationMSec)
        return item.isWeb
            ? String(format: String(localized: "Web address, %@", comment: "media stream"), duration)
            : duration
    }

    func spokenDetail(for item: StreamItem) -> String {
        if item.isLive {
            return String(localized: "Web address, live", comment: "media stream")
        }
        let duration = Self.spokenText(item.durationMSec)
        return item.isWeb
            ? String(format: String(localized: "Web address, %@", comment: "media stream"), duration)
            : duration
    }

    // MARK: - Playlist

    private func path(for item: StreamItem) -> String {
        item.isWeb
            ? item.location
            : directory.appendingPathComponent(item.id.uuidString, isDirectory: true)
                .appendingPathComponent(item.location).path
    }

    private func savePlaylist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: PREF_STREAM_PLAYLIST)
        }
    }

    func addFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isPreparing = true

        // A picked file is only readable while its security scope is held and
        // the playlist outlives this call, so it keeps a copy owned by the app.
        let directory = self.directory
        DispatchQueue.global(qos: .userInitiated).async {
            var added = [StreamItem]()
            var failure: String?

            for url in urls {
                let id = UUID()
                let folder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
                let copy = folder.appendingPathComponent(url.lastPathComponent)
                let scoped = url.startAccessingSecurityScopedResource()
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    try FileManager.default.copyItem(at: url, to: copy)
                } catch {
                    failure = error.localizedDescription
                }
                if scoped {
                    url.stopAccessingSecurityScopedResource()
                }

                if let info = TeamTalkClient.mediaFileInfo(path: copy.path),
                   info.audioFmt.nSampleRate > 0 || info.videoFmt.nWidth > 0 {
                    added.append(StreamItem(id: id, name: url.lastPathComponent, location: url.lastPathComponent,
                                            isWeb: false, durationMSec: Double(info.uDurationMSec),
                                            hasVideo: info.videoFmt.nWidth > 0))
                } else {
                    try? FileManager.default.removeItem(at: folder)
                    if failure == nil {
                        failure = String(format: String(localized: "%@ cannot be streamed", comment: "media stream"),
                                         url.lastPathComponent)
                    }
                }
            }

            DispatchQueue.main.async {
                self.itemsAdded(added, failure: failure)
            }
        }
    }

    /// A web radio or a file on a web server
    func addWebAddress(_ text: String) {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), let scheme = url.scheme?.lowercased(),
              ["http", "https", "rtmp", "rtsp", "mms"].contains(scheme) else {
            errorMessage = String(localized: "Enter a web address that starts with http or https", comment: "media stream")
            return
        }
        isPreparing = true
        logDiagnostic("Stream: probing web address, scheme \(scheme)")

        // opening the address waits for the server
        DispatchQueue.global(qos: .userInitiated).async {
            var added = [StreamItem]()
            var failure: String?
            if let info = TeamTalkClient.mediaFileInfo(path: address),
               info.audioFmt.nSampleRate > 0 || info.videoFmt.nWidth > 0 {
                added.append(StreamItem(id: UUID(), name: url.host ?? address, location: address, isWeb: true,
                                        durationMSec: Double(info.uDurationMSec), hasVideo: info.videoFmt.nWidth > 0))
            } else {
                failure = String(localized: "This web address cannot be streamed", comment: "media stream")
            }

            DispatchQueue.main.async {
                self.itemsAdded(added, failure: failure)
            }
        }
    }

    private func itemsAdded(_ added: [StreamItem], failure: String?) {
        isPreparing = false
        items.append(contentsOf: added)
        savePlaylist()
        logDiagnostic("Stream: \(added.count) item(s) added, failure: \(failure ?? "none")")

        if let failure {
            errorMessage = failure
        }
        guard let first = added.first else { return }

        if !isStreaming {
            select(first)
        }
        announceForAccessibility(
            added.count == 1
                ? String(format: String(localized: "%@ added to the playlist", comment: "media stream"), first.name)
                : String(format: String(localized: "%d files added to the playlist", comment: "media stream"), added.count)
        )
    }

    func select(_ item: StreamItem) {
        guard item.id != currentID else { return }
        stop()
        stopPreview()
        currentID = item.id
        positionMSec = 0
    }

    func remove(_ item: StreamItem) {
        if item.id == currentID {
            stop()
            stopPreview()
        }
        if !item.isWeb {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(item.id.uuidString, isDirectory: true))
        }
        items.removeAll { $0.id == item.id }
        if item.id == currentID {
            currentID = items.first?.id
            positionMSec = 0
        }
        savePlaylist()
    }

    func remove(at offsets: IndexSet) {
        for item in offsets.map({ items[$0] }) {
            remove(item)
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        savePlaylist()
    }

    private func index(offsetBy offset: Int) -> Int? {
        guard let index = items.firstIndex(where: { $0.id == currentID }), !items.isEmpty else { return nil }
        let next = index + offset
        if items.indices.contains(next) {
            return next
        }
        // past either end only when the whole list repeats
        return repeatMode == .all ? (next + items.count) % items.count : nil
    }

    var hasNext: Bool {
        index(offsetBy: 1) != nil
    }

    var hasPrevious: Bool {
        index(offsetBy: -1) != nil
    }

    func playNext() {
        jump(by: 1)
    }

    func playPrevious() {
        jump(by: -1)
    }

    /// Goes to another item of the list, and keeps streaming if it was streaming
    private func jump(by offset: Int) {
        guard let index = index(offsetBy: offset) else { return }
        let wasStreaming = isStreaming
        stop()
        stopPreview()
        currentID = items[index].id
        positionMSec = 0
        if wasStreaming {
            startSoon()
        }
    }

    /// What follows the end of a file
    private func advance() {
        switch repeatMode {
        case .one:
            positionMSec = 0
            startSoon()
        case .all, .off:
            if let index = index(offsetBy: 1) {
                currentID = items[index].id
                positionMSec = 0
                startSoon()
            } else {
                positionMSec = 0
                announceForAccessibility(String(localized: "Streaming finished", comment: "media stream"))
            }
        }
    }

    /// The stream that just ended is still being closed by the library
    private func startSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.start()
        }
    }

    // MARK: - Streaming

    private var gainLevel: INT32 {
        let gain = Double(SOUND_GAIN_DEFAULT.rawValue) * volumePercent / 100
        return INT32(min(max(gain, Double(SOUND_GAIN_MIN.rawValue)), Double(SOUND_GAIN_MAX.rawValue)))
    }

    private var videoCodec: VideoCodec {
        if hasVideo && sendVideo && canStreamVideo {
            return TeamTalkVideoCodec.makeWebMVP8Codec(targetBitrate: DEFAULT_MEDIAFILE_VIDEO_BITRATE)
        }
        return TeamTalkVideoCodec.makeNoCodec()
    }

    /// The position has to be inside the file
    private var startOffset: UInt32 {
        isLive ? 0 : UInt32(max(0, min(positionMSec, durationMSec - 1000)))
    }

    func start() {
        guard let current, canStart, state == .idle else { return }
        stopPreview()

        let offset = startOffset
        if TeamTalkClient.shared.startStreamingMediaFile(
            path: path(for: current),
            offsetMSec: offset,
            paused: false,
            gainLevel: gainLevel,
            videoCodec: videoCodec
        ) {
            positionMSec = Double(offset)
            active = true
            state = .playing
            logDiagnostic("Stream: started, web=\(current.isWeb) video=\(current.hasVideo) offset=\(offset) gain=\(gainLevel)")
        } else {
            logDiagnostic("Stream: FAILED to start, web=\(current.isWeb) flags=\(String(TeamTalkClient.shared.flags.rawValue, radix: 16))")
            errorMessage = String(localized: "Failed to stream media file", comment: "media stream")
        }
    }

    func togglePause() {
        guard isStreaming else { return }

        let pause = state == .playing
        if TeamTalkClient.shared.updateStreamingMediaFile(
            offsetMSec: TeamTalkClient.mediaPlaybackOffsetIgnore,
            paused: pause,
            gainLevel: gainLevel,
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
        logDiagnostic("Stream: stopped")
    }

    func skip(seconds: Double) {
        setPosition(positionMSec + seconds * 1000)
    }

    /// Position chosen by the user. The slider reports every step of a drag, so
    /// the stream is only moved once the value has settled.
    func setPosition(_ msec: Double) {
        guard !isLive else { return }
        positionMSec = min(max(0, msec), max(0, durationMSec - 1000))

        pendingSeek?.cancel()
        pendingSeek = nil
        guard isStreaming || isPreviewing else { return }

        let seek = DispatchWorkItem { [weak self] in
            self?.seek()
        }
        pendingSeek = seek
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: seek)
    }

    private func seek() {
        pendingSeek = nil
        if isStreaming {
            TeamTalkClient.shared.updateStreamingMediaFile(
                offsetMSec: UInt32(positionMSec),
                paused: state == .paused,
                gainLevel: gainLevel,
                videoCodec: videoCodec
            )
        } else if isPreviewing {
            TeamTalkClient.shared.updateLocalPlayback(
                session: previewSession,
                offsetMSec: UInt32(positionMSec),
                paused: false,
                gainLevel: gainLevel
            )
        } else {
            return
        }
        // progress reported before the seek took effect would move the slider back
        ignoreProgressUntil = Date().addingTimeInterval(1.0)
    }

    private func applyVolume() {
        if isStreaming {
            TeamTalkClient.shared.updateStreamingMediaFile(
                offsetMSec: TeamTalkClient.mediaPlaybackOffsetIgnore,
                paused: state == .paused,
                gainLevel: gainLevel,
                videoCodec: videoCodec
            )
        } else if isPreviewing {
            TeamTalkClient.shared.updateLocalPlayback(
                session: previewSession,
                offsetMSec: TeamTalkClient.mediaPlaybackOffsetIgnore,
                paused: false,
                gainLevel: gainLevel
            )
        }
    }

    // MARK: - Preview

    /// Plays the file on this device only, from the chosen position. Stopping it
    /// leaves the position where it was heard, to start streaming from there.
    func togglePreview() {
        if isPreviewing {
            stopPreview()
            return
        }
        guard let current, !isStreaming else { return }

        previewSession = TeamTalkClient.shared.initLocalPlayback(
            path: path(for: current),
            offsetMSec: startOffset,
            paused: false,
            gainLevel: gainLevel
        )
        isPreviewing = previewSession > 0
        logDiagnostic("Stream: preview \(isPreviewing ? "started" : "FAILED to start")")
        if !isPreviewing {
            errorMessage = String(localized: "Failed to play the file", comment: "media stream")
        }
    }

    func stopPreview() {
        guard isPreviewing else { return }
        TeamTalkClient.shared.stopLocalPlayback(session: previewSession)
        previewSession = 0
        isPreviewing = false
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
            stopPreview()
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
                announceForAccessibility(
                    String(format: String(localized: "Streaming %@", comment: "media stream"), fileName)
                )
            case MFS_PLAYING:
                state = .playing
                updateProgress(info)
            case MFS_PAUSED:
                state = .paused
                updateProgress(info)
            case MFS_FINISHED:
                logDiagnostic("Stream: finished")
                stop()
                advance()
            case MFS_ERROR:
                logDiagnostic("Stream: ERROR reported by the library")
                stop()
                errorMessage = String(localized: "Error while streaming media file", comment: "media stream")
            case MFS_ABORTED:
                stop()
            default:
                break
            }

        case CLIENTEVENT_LOCAL_MEDIAFILE:
            guard isPreviewing, m.nSource == previewSession else { break }
            let info = TeamTalkMessagePayload.mediaFileInfo(from: m)
            switch info.nStatus {
            case MFS_PLAYING:
                updateProgress(info)
            case MFS_FINISHED, MFS_ERROR, MFS_ABORTED:
                stopPreview()
            default:
                break
            }

        default:
            break
        }
    }
}
