//
//  SwiftUIView.swift
//  
//
//  Created by Alex.M on 07.07.2022.
//

import SwiftUI

@MainActor
struct MessageTextView: View {

    @Environment(\.chatTheme) private var theme

    /// Large enough to show the domain and icon, if needed, for most pages.
    private static let minLinkPreviewWidth: CGFloat = 140

    let attributedText: AttributedString
    let userType: UserType
    let params: MessageCustomizationParameters

    var previewLinks: [URL] {
        Array(attributedText.urls.filter(params.shouldShowPreviewForLink).prefix(params.linkPreviewLimit))
    }

    var body: some View {
        if !attributedText.characters.isEmpty {
            VStack(alignment: .leading) {
                if attributedText.containsQuote {
                    // isaCloud: a text with quotes is drawn as a tree of text and quotes, nested quotes inside their quote
                    // (see AttributedString+Quote.swift)
                    nodesView(attributedText.textTree)
                } else {
                    Text(attributedText)
                        .foregroundStyle(theme.colors.messageText(userType))
                }

                if !previewLinks.isEmpty {
                    VStack(alignment: userType == .current ? .trailing : .leading) {
                        // We use .enumerated(), and \.offset as the id, so that a message with duplicate links will show a preview for each.
                        ForEach(Array(previewLinks.enumerated()), id: \.offset) { _, url in
                            LinkPreviewView(url: url)
                        }
                    }
                    .frame(minWidth: Self.minLinkPreviewWidth)
                }
            }
            .font(Font(params.font as CTFont))
        }
    }
}

extension MessageTextView {

    /// isaCloud: the text and quotes of a message, one under the other.
    private func nodesView(_ nodes: [TextNode]) -> AnyView {
        AnyView(
            VStack(alignment: .leading) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    switch node {
                    case .text(let text):
                        Text(text)
                            .foregroundStyle(theme.colors.messageText(userType))
                    case .quote(let children):
                        quoteView(children)
                    }
                }
            }
        )
    }

    /// isaCloud: a quote: its content with ONE bar on the left, as tall as the whole quote, however many lines it takes and
    /// however many quotes are nested in it (they have their own bar inside this one).
    private func quoteView(_ children: [TextNode]) -> some View {
        let color = theme.colors.messageText(userType)
        return HStack(alignment: .top, spacing: 8) {
            // the bar takes the height of the content beside it, because of the fixedSize below
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color.opacity(0.6))
                .frame(width: 3)
            nodesView(children)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct MessageTextView_Previews: PreviewProvider {
    static var previews: some View {
        MessageTextView(
            attributedText: .init("Look at [this website](https://example.org)"), // no markdown
            userType: .other,
            params: MessageCustomizationParameters(
                shouldShowPreviewForLink: { _ in true }
            ))
        MessageTextView(
            attributedText: "Look at [this website](https://example.org)",
            userType: .other,
            params: MessageCustomizationParameters(
                shouldShowPreviewForLink: { _ in true }
            )
        )
        MessageTextView(
            attributedText: "[@Dan](mention://user/123456789) look at [this website](https://example.org)!",
            userType: .other,
            params: MessageCustomizationParameters(
                shouldShowPreviewForLink: { $0.scheme != "mention" }
            ))
    }
}
