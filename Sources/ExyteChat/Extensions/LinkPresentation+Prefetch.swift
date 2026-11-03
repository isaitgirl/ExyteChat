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
        // isaCloud: the wait ends at the first of two events (all fetches done, or the deadline), through a one-shot gate.
        // A task group would not do: cancelling it does not interrupt LPMetadataProvider.startFetchingMetadata, which
        // ignores cancellation, so the caller would stay blocked until the slowest fetch finished (2.7 s and 4.6 s
        // against a 2 s timeout in tests). The fetches run in unstructured tasks, so they keep going after the wait ends
        // and still fill the cache, which is what we want for the next time the user opens the same chat.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let gate = PrefetchGate(continuation)
            Task {
                await withTaskGroup(of: Void.self) { fetches in
                    for url in pending {
                        fetches.addTask {
                            await fetchAndCache(url, timeout: timeout)
                        }
                    }
                    await fetches.waitForAll()
                }
                gate.resume()
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                gate.resume()
            }
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

/// isaCloud: resumes the continuation of `LinkPreviewPrefetcher.prefetch` only once, whichever of its two tasks calls
/// `resume()` first. The later call does nothing.
private final class PrefetchGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var resumed = false

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func resume() {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume()
    }
}
