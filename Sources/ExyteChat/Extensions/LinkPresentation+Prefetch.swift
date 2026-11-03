//
//  LinkPresentation+Prefetch.swift
//  Chat
//

// LinkPresentation is not yet updated to support strict concurrency checking (see LinkPresentation+View.swift).
@preconcurrency import LinkPresentation
import Foundation

/// isaCloud: fetches link previews before the chat scrolls to a message.
/// Without this, rows with links start as a small placeholder and grow when the preview arrives, which pushes the
/// rows above them (the list is inverted, so newer rows are pushed away from the target message).
/// Fetched metadata goes into the same in-memory cache that LinkPreviewView reads from.
public enum LinkPreviewPrefetcher {

    /// Fetches the previews of `urls` that are not cached yet, in parallel.
    /// Returns when all of them finished or when `timeout` seconds have passed, whichever comes first. Never throws.
    public static func prefetch(_ urls: [URL], timeout: TimeInterval) async {
        var seen = Set<URL>()
        let pending = urls.filter { url in
            if LinkPreviewView.cache.get(forURL: url) != nil {
                return false
            }
            return seen.insert(url).inserted
        }
        guard !pending.isEmpty else {
            return
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await withTaskGroup(of: Void.self) { fetches in
                    for url in pending {
                        fetches.addTask {
                            await fetchAndCache(url, timeout: timeout)
                        }
                    }
                    await fetches.waitForAll()
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            }
            // The first child to finish (all fetches, or the deadline) ends the wait.
            _ = await group.next()
            group.cancelAll()
        }
    }

    private static func fetchAndCache(_ url: URL, timeout: TimeInterval) async {
        let provider = LPMetadataProvider()
        provider.timeout = timeout
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else {
            return
        }
        LinkPreviewView.cache.insert(metadata, forURL: url)
    }
}
