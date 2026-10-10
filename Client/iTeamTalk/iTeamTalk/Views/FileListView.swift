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

import PhotosUI
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// A photo or a video of the library, copied to a file the app can upload
struct PickedMediaFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            try PickedMediaFile(copying: received.file)
        }
        FileRepresentation(importedContentType: .image) { received in
            try PickedMediaFile(copying: received.file)
        }
    }

    /// The file handed over is only valid until the closure returns
    init(copying file: URL) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("picked", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent(file.lastPathComponent)
        try FileManager.default.copyItem(at: file, to: url)
    }
}

struct FileListView: View {
    @ObservedObject var model: FileListModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var showingFileImporter = false
    @State private var showingPhotoPicker = false
    @State private var pickedPhotos = [PhotosPickerItem]()

    var body: some View {
        List {
            if !model.uploads.isEmpty {
                Section("Uploading") {
                    ForEach(model.uploads) { transfer in
                        UploadRow(transfer: transfer) {
                            model.cancelTransfer(transfer)
                        }
                    }
                }
            }

            if model.files.isEmpty {
                Group {
                    if model.channelID > 0 {
                        Text("No files in this channel")
                    } else {
                        Text("Join a channel to see its files")
                    }
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            ForEach(model.files) { file in
                fileRow(file)
            }
        }
        .navigationTitle("Files")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose Files", systemImage: "folder")
                    }
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Photos and Videos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Image(systemName: "arrow.up.doc")
                }
                .accessibilityLabel("Upload file")
                .accessibilityHint("Uploads files or photos to the channel")
                .disabled(!model.canUpload)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                model.uploadFiles(urls)
            case .failure(let error):
                model.errorMessage = error.localizedDescription
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $pickedPhotos,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: pickedPhotos) { items in
            guard !items.isEmpty else { return }
            pickedPhotos = []
            Task {
                for item in items {
                    let picked = try? await item.loadTransferable(type: PickedMediaFile.self)
                    await MainActor.run {
                        if let picked {
                            model.uploadOwnedFile(picked.url)
                        } else {
                            model.errorMessage = String(localized: "Failed to upload file", comment: "file list")
                        }
                    }
                }
            }
        }
        .sheet(item: $model.sharedFile) { shared in
            ActivityView(items: [shared.url])
        }
        .sheet(item: $model.previewFile) { preview in
            QuickLookView(url: preview.url)
                .ignoresSafeArea()
        }
        .alert("Error", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .alert("Delete File",
            isPresented: Binding(
                get: { model.filePendingDeletion != nil },
                set: { if !$0 { model.filePendingDeletion = nil } }
            ),
            presenting: model.filePendingDeletion
        ) { file in
            Button("Delete", role: .destructive) {
                model.deleteFile(file)
            }
            Button("Cancel", role: .cancel) {}
        } message: { file in
            Text("Delete \"\(file.name)\" from the channel?")
        }
    }

    @ViewBuilder
    private func fileRow(_ file: ChannelFile) -> some View {
        let download = model.download(for: file)
        let isDownloaded = model.localURL(for: file) != nil

        HStack(spacing: 10) {
            Image(systemName: "doc")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(2)
                Text(model.subtitle(for: file))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let download {
                    ProgressView(value: download.fraction)
                        .accessibilityHidden(true)
                }
            }

            Spacer(minLength: 12)

            if download != nil {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } else if isDownloaded {
                Image(systemName: "eye")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            } else if model.canDownload {
                Image(systemName: "arrow.down.circle")
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusText(download: download, isDownloaded: isDownloaded))
        .accessibilityHint(hintText(download: download, isDownloaded: isDownloaded))
        .contentShape(Rectangle())
        .onTapGesture {
            if let download {
                model.cancelTransfer(download)
            } else {
                model.selectFile(file)
            }
        }
        // VoiceOver gets them once and by name. With the two swipe actions
        // left in while it runs, each showed up twice in the rotor.
        .accessibilityActions {
            if isDownloaded {
                Button("Share") {
                    model.shareFile(file)
                }
            }
            Button("Delete") {
                model.filePendingDeletion = file
            }
        }
        .swipeActions(edge: .trailing) {
            if !voiceOverEnabled {
                Button {
                    model.filePendingDeletion = file
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading) {
            if isDownloaded && !voiceOverEnabled {
                Button {
                    model.shareFile(file)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(.blue)
            }
        }
    }

    private func statusText(download: FileTransferProgress?, isDownloaded: Bool) -> String {
        if let download {
            return String(format: String(localized: "Downloading, %d %%", comment: "file list"), download.percent)
        }
        if isDownloaded {
            return String(localized: "Downloaded", comment: "file list")
        }
        return ""
    }

    private func hintText(download: FileTransferProgress?, isDownloaded: Bool) -> String {
        if download != nil {
            return String(localized: "Cancels the download", comment: "file list")
        }
        if isDownloaded {
            return String(localized: "Opens the file", comment: "file list")
        }
        if model.canDownload {
            return String(localized: "Downloads the file", comment: "file list")
        }
        return ""
    }
}

private struct UploadRow: View {
    let transfer: FileTransferProgress
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transfer.fileName)
                    .font(.body)
                    .lineLimit(2)
                ProgressView(value: transfer.fraction)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 12)

            Image(systemName: "xmark.circle")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(String(format: String(localized: "Uploading, %d %%", comment: "file list"), transfer.percent))
        .accessibilityHint(String(localized: "Cancels the upload", comment: "file list"))
        .contentShape(Rectangle())
        .onTapGesture(perform: cancel)
    }
}

/// The system preview: plays audio and video and shows documents and images
struct QuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
