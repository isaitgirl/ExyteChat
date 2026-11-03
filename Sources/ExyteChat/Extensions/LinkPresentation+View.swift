//
//  LinkPresentation+View.swift
//  Chat
//
//  Created by Matthew Fennell on 25/03/2025.
//

// LinkPresentation is not yet updated to support strict concurrency checking.
// LPLinkMetadata is not sendable; meanwhile, startFetchingMetadata(for:) uses a background thread and runs in a
// nonisolated context.
// Therefore, LPLinkMetadata is not usable from the main actor until Apple updates the library.
// Once LinkPresentation supports structured concurrency, we should remove the @preconcurrency annotation.
@preconcurrency import LinkPresentation
import SwiftUI

/// Lightweight wrapper around LPLinkView, that allows for more convenient use from SwiftUI.
private struct LinkViewRepresentable: UIViewRepresentable {

    let metadata: LinkPreviewMetadata
    /// isaCloud: the enriched card takes the width the row offers; the placeholder pill keeps its own width.
    let fillsWidth: Bool

    func makeUIView(context: Context) -> LPLinkView {
        switch metadata {
        case .placeholder(let url):
            LPLinkView(url: url)
        case .enriched(let metadata):
            LPLinkView(metadata: metadata)
        }
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {}

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LPLinkView, context: Context) -> CGSize? {
        let proposedWidth = proposal.width ?? .greatestFiniteMagnitude
        let fit = uiView.sizeThatFits(
            CGSize(width: proposedWidth, height: .greatestFiniteMagnitude)
        )
        let height = proposal.height ?? fit.height
        // isaCloud: the height is the one proposed (the card has a fixed height); LPLinkView crops its content to it.
        let width = fillsWidth ? (proposal.width ?? fit.width) : fit.width
        return CGSize(width: width, height: height)
    }
}

/// In our default chat view, link previews appear in the message itself.
/// Inside the message, there is limited space, and if multiple links are given, the default link preview design, with title, image, video etc takes up too much space.
/// Unfortunately, Apple does not let us customise the LPLinkView presentation (e.g. hiding the preview image), apart from modifying the view's size.
/// Therefore, create a small wrapper around LinkViewRepresentable, which presents the preview in a small "pill" form.
private struct PlaceholderOrEnrichedLinkPillView: View {

    private let metadata: LinkPreviewMetadata

    init(url: URL) {
        self.metadata = LinkPreviewMetadata.placeholder(for: url)
    }

    init(metadata: LPLinkMetadata) {
        self.metadata = LinkPreviewMetadata.enriched(with: metadata)
    }

    var body: some View {
        LinkViewRepresentable(metadata: metadata, fillsWidth: isEnriched)
    }

    private var isEnriched: Bool {
        if case .enriched = metadata {
            return true
        }
        return false
    }
}

/// PlaceholderOrEnrichedLinkPillView has two mutually exclusive cases - either displaying a placeholder, or enriched content.
/// To switch from one case to the other, you need to create a new view.
/// This is inconvenient for consumers since you have to keep track of whether the enriched metadata has loaded or not.
///
/// Therefore, this view manages this complexity, hiding the state of whether the enriched metadata is loaded or not.
/// Since this view is the only view generating link preview metadata, it also manages the cache.
struct LinkPreviewView: View {

    /// isaCloud: height of the card in every state (loading, preview, unavailable). Rows with links used to start as a small pill and
    /// grow when the preview arrived, which pushed the rows above them; with a fixed height the row never changes size.
    static let cardHeight: CGFloat = 120

    /// isaCloud: how long the provider may take before the card shows "Preview not available".
    private static let fetchTimeout: TimeInterval = 5

    @State var metadata: LinkPreviewMetadata
    /// isaCloud: the preview failed (or timed out) and the card shows the unavailable state instead of the pill.
    @State private var unavailable: Bool
    static let cache = LinkMetadataCache()

    init(url: URL) {
        // isaCloud: the @State values are set with State(initialValue:), not assigned in init: an assignment to a @State that
        // already has a default value does not reliably reach the view, and then a row recreated after a failure would fetch again.
        if let cached = Self.cache.get(forURL: url) {
            _metadata = State(initialValue: .enriched(with: cached))
            _unavailable = State(initialValue: false)
        } else {
            _metadata = State(initialValue: .placeholder(for: url))
            _unavailable = State(initialValue: Self.cache.recentlyFailed(url))
        }
    }

    private func fetchMetadata(for url: URL) async {
        let provider = LPMetadataProvider()
        provider.timeout = Self.fetchTimeout
        let metadata = try? await provider.startFetchingMetadata(for: url)
        guard let metadata = metadata else {
            // isaCloud: a fetch cancelled because the row left the screen says nothing about the page.
            if !Task.isCancelled {
                Self.cache.markFailed(url)
                unavailable = true
            }
            return
        }
        self.metadata = .enriched(with: metadata)
        Self.cache.insert(metadata, forURL: url)
    }

    var body: some View {
        // Use ZStack instead of Group as animation modifier doesn't work with Group.
        ZStack(alignment: .topLeading) {
            if unavailable {
                unavailableCard
            } else {
                switch metadata {
                case .placeholder(let url):
                    PlaceholderOrEnrichedLinkPillView(url: url)
                        .task {
                            await fetchMetadata(for: url)
                        }
                case .enriched(let metadata):
                    PlaceholderOrEnrichedLinkPillView(metadata: metadata)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .animation(.default, value: metadata)
    }

    /// isaCloud: the card when there is no preview: a discreet icon and text, centred, on a slightly highlighted background.
    private var unavailableCard: some View {
        VStack(spacing: 6) {
            Image(systemName: "link.badge.plus")
                .font(.title3)
            Text(NSLocalizedString("Preview not available", comment: ""))
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary.opacity(0.12))
    }
}

#Preview {
    LinkPreviewView(url: URL(string: "https://example.org")!)
}
