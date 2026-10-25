//
//  ReactionGroup.swift
//  isaCloud: new file (reactions grouped by emoji / who reacted with what)
//  Chat
//

import Foundation

/// All the reactions of one message that use the same emoji, e.g. everybody who reacted with ❤️.
struct ReactionGroup: Identifiable, Hashable {

    var id: String { emoji }

    let emoji: String

    /// the reactions with this emoji, newest first
    let reactions: [Reaction]

    var count: Int { reactions.count }

    var users: [User] { reactions.map(\.user) }

    var containsCurrentUser: Bool {
        reactions.contains { $0.user.isCurrentUser }
    }

    /// the reaction that represents the group in a bubble: the one of the current user if there is one, else the newest
    var representative: Reaction {
        reactions.first { $0.user.isCurrentUser } ?? reactions[0]
    }

    var latest: Date {
        reactions[0].createdAt
    }

    /// Groups the emoji reactions by emoji. The groups are ordered by their newest reaction (newest first);
    /// groups whose newest reaction has the same time are ordered by emoji, so the order stays stable.
    static func groups(of reactions: [Reaction]) -> [ReactionGroup] {
        let byEmoji = Dictionary(grouping: reactions.filter { $0.emoji != nil }, by: { $0.emoji! })
        return byEmoji
            .map { emoji, reactions in
                ReactionGroup(emoji: emoji, reactions: reactions.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { lhs, rhs in
                lhs.latest != rhs.latest ? lhs.latest > rhs.latest : lhs.emoji < rhs.emoji
            }
    }
}
