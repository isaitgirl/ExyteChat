//
//  ShareSheet.swift
//  Chat
//

import SwiftUI
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum AttachmentSharing {
    // isaCloud: the app caches files with the hex encoded mime type as extension, which the share sheet doesn't recognize
    // (no "Save Image" / "Save Video"): share a temporary copy with the real extension instead
    private static func localFileWithKnownExtension(for attachment: Attachment) -> URL {
        let url = attachment.full
        if let known = UTType(filenameExtension: url.pathExtension), !known.isDynamic {
            return url
        }
        guard let mimeType = attachment.mimeType,
              let fileExtension = UTType(mimeType: mimeType)?.preferredFilenameExtension else {
            return url
        }
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
            return destinationURL
        } catch {
            print("[AttachmentSharing] Failed to copy attachment for sharing: \(error)")
            return url
        }
    }

    /// Resolves a local, shareable file URL for an attachment, downloading it first if it's remote.
    static func prepareForSharing(_ attachment: Attachment) async -> URL? {
        if attachment.full.isFileURL {
            return localFileWithKnownExtension(for: attachment)
        }

        do {
            let (tempURL, response) = try await URLSession.shared.download(from: attachment.full)
            let fileExtension = response.suggestedFilename.flatMap { ($0 as NSString).pathExtension.nonEmpty }
                ?? attachment.full.pathExtension.nonEmpty
                ?? (attachment.type == .video ? "mp4" : "jpg")

            let destinationURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)
            try FileManager.default.moveItem(at: tempURL, to: destinationURL)
            return destinationURL
        } catch {
            print("[AttachmentSharing] Failed to download attachment for sharing: \(error)")
            return nil
        }
    }

    /// Resolves local, shareable file URLs for multiple attachments, downloading remote ones concurrently.
    /// Attachments that fail to download are skipped.
    static func prepareForSharing(_ attachments: [Attachment]) async -> [URL] {
        await withTaskGroup(of: (Int, URL?).self) { group in
            for (index, attachment) in attachments.enumerated() {
                group.addTask {
                    (index, await prepareForSharing(attachment))
                }
            }
            var urlsByIndex = [Int: URL]()
            for await (index, url) in group {
                urlsByIndex[index] = url
            }
            return urlsByIndex.keys.sorted().compactMap { urlsByIndex[$0] }
        }
    }
}
