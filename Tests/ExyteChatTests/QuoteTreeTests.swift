//
//  QuoteTreeTests.swift
//
//  isaCloud: nested quotes. A text is cut by the depth of its quote attribute, and the cuts form a tree: a quote of depth 2 sits
//  inside the quote of depth 1.
//

import Testing
import Foundation
@testable import ExyteChat

struct QuoteTreeTests {

    private func piece(_ text: String, depth: Int) -> AttributedString {
        var result = AttributedString(text)
        if depth > 0 {
            result.quoteDepth = depth
        }
        return result
    }

    private func describe(_ nodes: [TextNode]) -> String {
        nodes.map { node in
            switch node {
            case .text(let text): return "t(\(String(text.characters)))"
            case .quote(let children): return "q[\(describe(children))]"
            }
        }.joined(separator: ",")
    }

    @Test("text without quotes has no quote")
    func noQuote() {
        #expect(AttributedString("oi").containsQuote == false)
    }

    @Test("the old boolean quote counts as depth 1")
    func booleanQuote() {
        var text = AttributedString("oi")
        text.quote = true
        #expect(text.containsQuote)
        #expect(text.textBlocks.map { $0.depth } == [1])
    }

    @Test("a quote and an answer make a quote node and a text node")
    func simpleQuote() {
        let text = piece("a", depth: 1) + AttributedString("\n") + piece("resposta", depth: 0)
        #expect(describe(text.textTree) == "q[t(a)],t(resposta)")
    }

    @Test("a quote inside a quote is a child of it, and the outer quote goes on after it")
    func nestedQuote() {
        let text = piece("avô", depth: 2) + piece("\n", depth: 1) + piece("pai", depth: 1) + AttributedString("\n") + piece("filho", depth: 0)
        #expect(describe(text.textTree) == "q[q[t(avô)],t(pai)],t(filho)")
    }

    @Test("lines of the same depth, with their line break, are one block")
    func sameDepthIsOneBlock() {
        let text = piece("a", depth: 2) + piece("\n", depth: 2) + piece("b", depth: 2)
        #expect(describe(text.textTree) == "q[q[t(a\nb)]]")
    }

    @Test("a quote that starts deeper than the first level still sits inside the levels above it")
    func startsDeep() {
        let text = piece("x", depth: 3)
        #expect(describe(text.textTree) == "q[q[q[t(x)]]]")
    }
}
