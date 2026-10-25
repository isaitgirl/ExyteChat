//
//  AttributedString+Quote.swift
//
//  isaCloud: quotes in a message. The app marks the quoted part of a message with the `quote` attribute and the message
//  bubble draws each quote as a block with ONE vertical bar on its left, no matter how many lines (or wrapped lines) it has.
//
//  Why an attribute: SwiftUI's `Text` cannot draw a bar beside a part of its text, and putting a "|" character at the start of each line
//  gives one bar per line, with gaps between them. A block with a bar that stretches over its full height needs a view of its own,
//  so MessageTextView splits the text into blocks (see `textBlocks`) and draws a view for each one.
//
//  How to use it (in the app):
//      var line = AttributedString("quoted text")
//      line.quote = true
//      message = line + AttributedString("\nanswer")
//  The line break between two quoted lines must be marked as quote too, otherwise they are drawn as two quotes.
//

import SwiftUI

// MARK: - The attribute

/// `true` on the parts of an AttributedString that are a quote.
public enum QuoteAttribute: AttributedStringKey {
    public typealias Value = Bool
    public static let name = "exyteChat.quote"
}

public extension AttributeScopes {
    /// The attributes of this library that are not part of SwiftUI's or Foundation's scopes.
    struct ChatAttributes: AttributeScope {
        public let quote: QuoteAttribute
    }

    var chat: ChatAttributes.Type { ChatAttributes.self }
}

public extension AttributeDynamicLookup {
    /// Makes `attributedString.quote = true` and `run.quote` work.
    subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.ChatAttributes, T>) -> T {
        self[T.self]
    }
}

// MARK: - Splitting a text into blocks

/// A part of a message text: either a quote or normal text.
struct TextBlock {
    let text: AttributedString
    let isQuote: Bool
}

extension AttributedString {

    /// Whether any part of the text is a quote.
    var containsQuote: Bool {
        runs.contains { $0.quote == true }
    }

    /// The text cut into consecutive blocks of the same kind (quote / not quote). The line breaks that separate two blocks are
    /// removed, because the views that draw the blocks are stacked and already leave a space between them.
    var textBlocks: [TextBlock] {
        var blocks: [TextBlock] = []
        for run in runs {
            let isQuote = run.quote == true
            let piece = AttributedString(self[run.range])
            if let last = blocks.last, last.isQuote == isQuote {
                // same kind as the previous run (for example a link in the middle of a quote): the same block
                var joined = last.text
                joined.append(piece)
                blocks[blocks.count - 1] = TextBlock(text: joined, isQuote: isQuote)
            } else {
                blocks.append(TextBlock(text: piece, isQuote: isQuote))
            }
        }
        return blocks
            .map { TextBlock(text: $0.text.removingEdgeLineBreaks(), isQuote: $0.isQuote) }
            .filter { !$0.text.characters.isEmpty }
    }

    /// The text without the line breaks at its start and its end.
    private func removingEdgeLineBreaks() -> AttributedString {
        var result = self
        while let first = result.characters.first, first.isNewline {
            result.characters.removeFirst()
        }
        while let last = result.characters.last, last.isNewline {
            result.characters.removeLast()
        }
        return result
    }
}
