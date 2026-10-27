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
//      line.quote = true                // a quote
//      line.quoteDepth = 2              // a quote inside a quote (the reply to a reply); `quote = true` is depth 1
//      message = line + AttributedString("\nanswer")
//  The line break between two quoted lines must be marked as quote too (with the smaller of their depths), otherwise they are
//  drawn as two quotes.
//
//  Nested quotes are drawn as in Conversations: a quote of depth 2 sits inside the quote of depth 1, so the outer bar covers the
//  whole quote, with the inner bar beside the lines of the inner quote only.
//

import SwiftUI

// MARK: - The attribute

/// `true` on the parts of an AttributedString that are a quote.
public enum QuoteAttribute: AttributedStringKey {
    public typealias Value = Bool
    public static let name = "exyteChat.quote"
}

/// How deep a quote is nested: 1 for a quote, 2 for a quote in a quote, and so on. Not set (or 0) is not a quote. `quote = true`
/// is the same as `quoteDepth = 1`.
public enum QuoteDepthAttribute: AttributedStringKey {
    public typealias Value = Int
    public static let name = "exyteChat.quoteDepth"
}

public extension AttributeScopes {
    /// The attributes of this library that are not part of SwiftUI's or Foundation's scopes.
    struct ChatAttributes: AttributeScope {
        public let quote: QuoteAttribute
        public let quoteDepth: QuoteDepthAttribute
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

/// A part of a message text: normal text (depth 0) or a quote of some depth.
struct TextBlock {
    let text: AttributedString
    let depth: Int

    var isQuote: Bool { depth > 0 }
}

/// A message text as a tree: normal text and quotes, each quote holding its own text and the quotes nested in it.
indirect enum TextNode {
    case text(AttributedString)
    case quote([TextNode])
}

extension AttributedString.Runs.Run {
    /// How deep this part is quoted: 0 when it is not a quote.
    var quotedDepth: Int {
        if let depth = self[QuoteDepthAttribute.self] {
            return max(depth, 0)
        }
        return self[QuoteAttribute.self] == true ? 1 : 0
    }
}

extension AttributedString {

    /// Whether any part of the text is a quote.
    var containsQuote: Bool {
        runs.contains { $0.quotedDepth > 0 }
    }

    /// The text cut into consecutive blocks of the same depth. The line breaks that separate two blocks are removed, because the
    /// views that draw the blocks are stacked and already leave a space between them.
    var textBlocks: [TextBlock] {
        var blocks: [TextBlock] = []
        for run in runs {
            let depth = run.quotedDepth
            let piece = AttributedString(self[run.range])
            if let last = blocks.last, last.depth == depth {
                // same depth as the previous run (for example a link in the middle of a quote): the same block
                var joined = last.text
                joined.append(piece)
                blocks[blocks.count - 1] = TextBlock(text: joined, depth: depth)
            } else {
                blocks.append(TextBlock(text: piece, depth: depth))
            }
        }
        return blocks
            .map { TextBlock(text: $0.text.removingEdgeLineBreaks(), depth: $0.depth) }
            .filter { !$0.text.characters.isEmpty }
    }

    /// The text as a tree: each group of blocks that are deeper than the current level becomes a quote holding what is in it.
    var textTree: [TextNode] {
        TextNode.tree(of: textBlocks)
    }
}

extension TextNode {

    static func tree(of blocks: [TextBlock]) -> [TextNode] {
        tree(of: blocks[...], level: 0)
    }

    private static func tree(of blocks: ArraySlice<TextBlock>, level: Int) -> [TextNode] {
        var nodes: [TextNode] = []
        var index = blocks.startIndex
        while index < blocks.endIndex {
            if blocks[index].depth <= level {
                nodes.append(.text(blocks[index].text))
                index += 1
            } else {
                var end = index
                while end < blocks.endIndex, blocks[end].depth > level {
                    end += 1
                }
                nodes.append(.quote(tree(of: blocks[index..<end], level: level + 1)))
                index = end
            }
        }
        return nodes
    }
}

extension AttributedString {

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
