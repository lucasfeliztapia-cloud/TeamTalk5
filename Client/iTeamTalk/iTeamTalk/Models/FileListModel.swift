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

struct ChannelFile: Identifiable, Equatable {
    let id: INT32
    let channelID: INT32
    let name: String
    let size: Int64
    let username: String
    let uploadTime: String

    /// Tells a file apart from a later upload that reuses its name.
    var fingerprint: String {
        "\(name)|\(size)|\(uploadTime)"
    }
}

struct FileTransferProgress: Identifiable, Equatable {
    let id: INT32
    let fileName: String
    let localPath: String
    let inbound: Bool
    var transferred: Int64
    var size: Int64

    var fraction: Double {
        size > 0 ? min(1.0, Double(transferred) / Double(size)) : 0
    }

    var percent: Int {
        Int((fraction * 100).rounded())
    }
}

struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}

final class FileListModel: ObservableObject {

    @Published var files = [ChannelFile]()
    @Published var transfers = [FileTransferProgress]()
    @Published var downloaded = [String: URL]()
    @Published var channelID: INT32 = 0
    @Published var canUpload = false
    @Published var canDownload = false
    @Published var errorMessage: String?
    @Published var filePendingDeletion: ChannelFile?
    @Published var sharedFile: SharedFile?
    @Published var previewFile: SharedFile?

    private var userRights: UInt32 = 0
    private var activeCommands = Set<INT32>()
    private var uploadCommands = [INT32: URL]()
    private var downloadCommands = [INT32: String]()
    private var downloadFingerprints = [String: String]()
    private var completedTransfers = Set<INT32>()
    // while a command runs, the files that arrive are the ones already in the
    // channel being joined, not news
    private var commandInProgress = false
    private var progressTimer: Timer?

    private let uploadsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("uploads", isDirectory: true)

    init() {
        // copies left behind if the app was closed during an upload
        try? FileManager.default.removeItem(at: uploadsDirectory)
    }

    deinit {
        progressTimer?.invalidate()
    }

    var uploads: [FileTransferProgress] {
        transfers.filter { !$0.inbound }
    }

    func download(for file: ChannelFile) -> FileTransferProgress? {
        transfers.first { $0.inbound && $0.fileName == file.name }
    }

    func localURL(for file: ChannelFile) -> URL? {
        guard let url = downloaded[file.fingerprint],
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    func subtitle(for file: ChannelFile) -> String {
        let size = ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file)
        return [size, file.username, file.uploadTime].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    // MARK: - Actions

    func selectFile(_ file: ChannelFile) {
        if download(for: file) != nil {
            return
        }
        if let url = localURL(for: file) {
            previewFile = SharedFile(url: url)
        } else {
            downloadFile(file)
        }
    }

    func shareFile(_ file: ChannelFile) {
        if let url = localURL(for: file) {
            sharedFile = SharedFile(url: url)
        }
    }

    /// A file the app already owns, like the copy handed over by the photo
    /// picker. It is moved, not copied again.
    func uploadOwnedFile(_ url: URL) {
        guard channelID > 0 else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        let directory = uploadsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let copy = directory.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: url, to: copy)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            errorMessage = error.localizedDescription
            return
        }

        let cmdid = TeamTalkClient.shared.sendFile(channelID: channelID, localFilePath: copy.path)
        if cmdid > 0 {
            activeCommands.insert(cmdid)
            uploadCommands[cmdid] = copy
        } else {
            try? FileManager.default.removeItem(at: directory)
            errorMessage = String(localized: "Failed to upload file", comment: "file list")
        }
    }

    func uploadFiles(_ urls: [URL]) {
        for url in urls {
            uploadFile(url)
        }
    }

    private func uploadFile(_ url: URL) {
        guard channelID > 0 else { return }

        // The picked file is only readable while its security scope is held and
        // the transfer outlives this call, so upload a copy owned by the app.
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let directory = uploadsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let copy = directory.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: copy)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            errorMessage = error.localizedDescription
            return
        }

        let cmdid = TeamTalkClient.shared.sendFile(channelID: channelID, localFilePath: copy.path)
        if cmdid > 0 {
            activeCommands.insert(cmdid)
            uploadCommands[cmdid] = copy
        } else {
            try? FileManager.default.removeItem(at: directory)
            errorMessage = String(localized: "Failed to upload file", comment: "file list")
        }
    }

    func downloadFile(_ file: ChannelFile) {
        // a requested download has no transfer until the server accepts it
        guard canDownload, download(for: file) == nil,
              !downloadFingerprints.values.contains(file.fingerprint) else { return }

        guard let destination = downloadURL(for: file.name) else {
            errorMessage = String(localized: "Failed to download file", comment: "file list")
            return
        }

        let cmdid = TeamTalkClient.shared.receiveFile(
            channelID: file.channelID,
            fileID: file.id,
            localFilePath: destination.path
        )
        if cmdid > 0 {
            activeCommands.insert(cmdid)
            downloadCommands[cmdid] = destination.path
            downloadFingerprints[destination.path] = file.fingerprint
        } else {
            errorMessage = String(localized: "Failed to download file", comment: "file list")
        }
    }

    func cancelTransfer(_ transfer: FileTransferProgress) {
        TeamTalkClient.shared.cancelFileTransfer(transferID: transfer.id)
        closeTransfer(transfer.id, fileName: transfer.fileName, localPath: transfer.localPath,
                      inbound: transfer.inbound, succeeded: false, failed: false)
    }

    func deleteFile(_ file: ChannelFile) {
        let cmdid = TeamTalkClient.shared.deleteFile(channelID: file.channelID, fileID: file.id)
        if cmdid > 0 {
            activeCommands.insert(cmdid)
        }
    }

    // MARK: - Local files

    /// Downloads go to the app's Documents folder, which the Files app shows.
    private func downloadURL(for fileName: String) -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        var name = (fileName as NSString).lastPathComponent
        if name.isEmpty || name == "." || name == ".." {
            name = "file"
        }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = documents.appendingPathComponent(name)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(base) (\(index))" : "\(base) (\(index)).\(ext)"
            candidate = documents.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    private func removeUploadCopy(_ localPath: String) {
        let copy = URL(fileURLWithPath: localPath).standardizedFileURL
        guard copy.path.hasPrefix(uploadsDirectory.standardizedFileURL.path) else { return }
        try? FileManager.default.removeItem(at: copy.deletingLastPathComponent())
    }

    // MARK: - State

    private func reloadFiles() {
        guard channelID > 0 else {
            files = []
            return
        }

        files = TeamTalkClient.shared.channelFiles(channelID: channelID).map { file in
            ChannelFile(
                id: file.nFileID,
                channelID: file.nChannelID,
                name: TeamTalkString.remoteFile(.fileName, from: file),
                size: file.nFileSize,
                username: TeamTalkString.remoteFile(.username, from: file),
                uploadTime: TeamTalkString.remoteFile(.uploadTime, from: file)
            )
        }.sorted {
            $0.name.caseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func updateRights() {
        canUpload = channelID > 0 && (userRights & USERRIGHT_UPLOAD_FILES.rawValue) != 0
        canDownload = (userRights & USERRIGHT_DOWNLOAD_FILES.rawValue) != 0
    }

    private func reset() {
        for transfer in transfers {
            closeTransfer(transfer.id, fileName: transfer.fileName, localPath: transfer.localPath,
                          inbound: transfer.inbound, succeeded: false, failed: false)
        }
        channelID = 0
        files = []
        activeCommands.removeAll()
        uploadCommands.removeAll()
        downloadCommands.removeAll()
        downloadFingerprints.removeAll()
        // transfer IDs start over on the next connection
        completedTransfers.removeAll()
        updateRights()
    }

    // MARK: - Transfers

    private func updateTransfer(_ transfer: FileTransfer) {
        let fileName = TeamTalkString.fileTransfer(.remoteFileName, from: transfer)
        let localPath = TeamTalkString.fileTransfer(.localFilePath, from: transfer)
        let inbound = transfer.bInbound != 0

        switch transfer.nStatus {
        case FILETRANSFER_ACTIVE:
            guard !completedTransfers.contains(transfer.nTransferID) else { return }
            let progress = FileTransferProgress(
                id: transfer.nTransferID,
                fileName: fileName,
                localPath: localPath,
                inbound: inbound,
                transferred: transfer.nTransferred,
                size: transfer.nFileSize
            )
            if let index = transfers.firstIndex(where: { $0.id == progress.id }) {
                transfers[index] = progress
            } else {
                transfers.append(progress)
            }
            startProgressTimer()
        case FILETRANSFER_FINISHED:
            closeTransfer(transfer.nTransferID, fileName: fileName, localPath: localPath,
                          inbound: inbound, succeeded: true, failed: false)
        case FILETRANSFER_ERROR:
            closeTransfer(transfer.nTransferID, fileName: fileName, localPath: localPath,
                          inbound: inbound, succeeded: false, failed: true)
        default:
            closeTransfer(transfer.nTransferID, fileName: fileName, localPath: localPath,
                          inbound: inbound, succeeded: false, failed: false)
        }
    }

    /// A transfer ends both through its event and through the progress timer, so
    /// only the first notice is handled.
    private func closeTransfer(_ transferID: INT32, fileName: String, localPath: String,
                               inbound: Bool, succeeded: Bool, failed: Bool) {
        guard completedTransfers.insert(transferID).inserted else { return }

        transfers.removeAll { $0.id == transferID }
        if transfers.isEmpty {
            progressTimer?.invalidate()
            progressTimer = nil
        }

        if inbound {
            let fingerprint = downloadFingerprints.removeValue(forKey: localPath)
                ?? files.first(where: { $0.name == fileName })?.fingerprint
            if succeeded {
                if let fingerprint {
                    downloaded[fingerprint] = URL(fileURLWithPath: localPath)
                }
                announceForAccessibility(
                    String(format: String(localized: "%@ downloaded", comment: "file list"), fileName)
                )
            } else {
                try? FileManager.default.removeItem(atPath: localPath)
            }
        } else {
            removeUploadCopy(localPath)
            if succeeded {
                announceForAccessibility(
                    String(format: String(localized: "%@ uploaded", comment: "file list"), fileName)
                )
            }
        }

        if failed {
            errorMessage = String(format: String(localized: "Failed to transfer %@", comment: "file list"), fileName)
        }
    }

    private func startProgressTimer() {
        guard progressTimer == nil else { return }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollTransfers()
        }
    }

    private func pollTransfers() {
        for transfer in transfers {
            if let info = TeamTalkClient.shared.fileTransferInfo(transferID: transfer.id) {
                updateTransfer(info)
            } else {
                closeTransfer(transfer.id, fileName: transfer.fileName, localPath: transfer.localPath,
                              inbound: transfer.inbound, succeeded: false, failed: false)
            }
        }
    }
}

// MARK: - TeamTalkEvent

extension FileListModel: TeamTalkEvent {
    func handleTTMessage(_ m: TTMessage) {
        switch m.nClientEvent {

        case CLIENTEVENT_CON_LOST:
            reset()

        case CLIENTEVENT_CMD_MYSELF_LOGGEDIN:
            let account = TeamTalkMessagePayload.userAccount(from: m)
            userRights = (account.uUserType & USERTYPE_ADMIN.rawValue) != 0 ? 0xFFFFFFFF : account.uUserRights
            updateRights()

        case CLIENTEVENT_CMD_MYSELF_LOGGEDOUT:
            userRights = 0
            reset()

        case CLIENTEVENT_CMD_USER_JOINED:
            let user = TeamTalkMessagePayload.user(from: m)
            if user.nUserID == TeamTalkClient.shared.myUserID {
                channelID = user.nChannelID
                reloadFiles()
                updateRights()
            }

        case CLIENTEVENT_CMD_USER_LEFT:
            let user = TeamTalkMessagePayload.user(from: m)
            if user.nUserID == TeamTalkClient.shared.myUserID {
                channelID = 0
                files = []
                updateRights()
            }

        case CLIENTEVENT_CMD_FILE_NEW, CLIENTEVENT_CMD_FILE_REMOVE:
            if TeamTalkMessagePayload.remoteFile(from: m).nChannelID == channelID {
                reloadFiles()
                if !commandInProgress {
                    playSound(m.nClientEvent == CLIENTEVENT_CMD_FILE_NEW ? .file_ADDED : .file_REMOVED)
                }
            }

        case CLIENTEVENT_FILETRANSFER:
            updateTransfer(TeamTalkMessagePayload.fileTransfer(from: m))

        case CLIENTEVENT_CMD_ERROR:
            if activeCommands.contains(m.nSource) {
                if let copy = uploadCommands[m.nSource] {
                    removeUploadCopy(copy.path)
                }
                if let path = downloadCommands[m.nSource] {
                    downloadFingerprints.removeValue(forKey: path)
                }
                errorMessage = TeamTalkString.clientError(TeamTalkMessagePayload.clientError(from: m))
            }

        case CLIENTEVENT_CMD_PROCESSING:
            commandInProgress = TeamTalkMessagePayload.isActive(m)
            if !TeamTalkMessagePayload.isActive(m) {
                activeCommands.remove(m.nSource)
                uploadCommands.removeValue(forKey: m.nSource)
                downloadCommands.removeValue(forKey: m.nSource)
            }

        default:
            break
        }
    }
}
