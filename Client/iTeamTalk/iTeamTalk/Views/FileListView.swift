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

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct FileListView: View {
    @ObservedObject var model: FileListModel
    @State private var showingFileImporter = false

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
                Button {
                    showingFileImporter = true
                } label: {
                    Image(systemName: "arrow.up.doc")
                        .accessibilityLabel("Upload file")
                }
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
        .sheet(item: $model.sharedFile) { shared in
            ActivityView(items: [shared.url])
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
                Image(systemName: "square.and.arrow.up")
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
        .swipeActions(edge: .trailing) {
            Button {
                model.filePendingDeletion = file
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
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
            return String(localized: "Shares or opens the file", comment: "file list")
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

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
