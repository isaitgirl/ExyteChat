//
//  LinkPresentation+Cache.swift
//  Chat
//
//  Created by Matthew Fennell on 25/03/2025.
//

import Foundation
import LinkPresentation

/// Generating the metadata to display in a link preview is expensive, and would occur every time we scroll past a message bubble with a link preview inside.
/// Therefore, we need a cache to prevent the enriched metadata from disappearing and reappearing every time we scroll past a message with a preview.
/// NSCache almost does what we want, but only works on class types, which doesn't work with the URL struct we'd like to use as the key.
/// Therefore: create a light wrapper around NSCache that does not require the caller to drop down to UIKit.
class LinkMetadataCache {

    /// isaCloud: for how long a URL whose preview failed (or timed out) is shown as unavailable, without asking the provider again.
    static let failureMemory: TimeInterval = 5 * 60

    private let nsCache = NSCache<NSURL, LPLinkMetadata>()

    /// isaCloud: URL -> when its preview failed. Read and written from the main thread by LinkPreviewView, but guarded anyway.
    private let failuresLock = NSLock()
    private var failures: [URL: Date] = [:]

    public func insert(_ metadata: LPLinkMetadata, forURL url: URL) {
        nsCache.setObject(metadata, forKey: url as NSURL)
    }

    public func get(forURL url: URL) -> LPLinkMetadata? {
        nsCache.object(forKey: url as NSURL)
    }

    /// isaCloud: remembers that the preview of `url` could not be loaded.
    public func markFailed(_ url: URL) {
        failuresLock.lock()
        defer { failuresLock.unlock() }
        failures[url] = Date()
    }

    /// isaCloud: true when the preview of `url` failed less than `failureMemory` seconds ago. Expired entries are dropped here.
    public func recentlyFailed(_ url: URL) -> Bool {
        failuresLock.lock()
        defer { failuresLock.unlock() }
        guard let failedAt = failures[url] else {
            return false
        }
        if Date().timeIntervalSince(failedAt) < Self.failureMemory {
            return true
        }
        failures[url] = nil
        return false
    }

}
