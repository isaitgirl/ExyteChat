//
//  ReactionPeople.swift
//  Chat
//
//  isaCloud: one line per person in the reaction details sheet
//

import Foundation

/// All the reactions one person gave to a message. A person can react with several emojis (XEP-0444 allows it).
struct PersonReactions: Identifiable, Hashable {

    var id: String { user.id }

    let user: User

    /// the person's reactions, newest first. Reactions with the same time keep the order they were given in,
    /// the last one being the newest (the app gives every reaction of a person the same time).
    let reactions: [Reaction]

    var emojis: [String] { reactions.compactMap(\.emoji) }

    var latest: Date { reactions.first?.createdAt ?? .distantPast }

    /// Groups the reactions by person. The current user comes first (when they have reactions),
    /// the others follow in alphabetical order.
    static func people(of reactions: [Reaction]) -> [PersonReactions] {
        var order: [String] = []
        var byUser: [String: [(index: Int, reaction: Reaction)]] = [:]
        for (index, reaction) in reactions.enumerated() where reaction.emoji != nil {
            if byUser[reaction.user.id] == nil { order.append(reaction.user.id) }
            byUser[reaction.user.id, default: []].append((index, reaction))
        }
        let people = order.map { id -> PersonReactions in
            let entries = byUser[id]!.sorted { lhs, rhs in
                lhs.reaction.createdAt != rhs.reaction.createdAt
                    ? lhs.reaction.createdAt > rhs.reaction.createdAt
                    : lhs.index > rhs.index
            }
            return PersonReactions(user: entries[0].reaction.user, reactions: entries.map(\.reaction))
        }
        return people.sorted { lhs, rhs in
            if lhs.user.isCurrentUser != rhs.user.isCurrentUser { return lhs.user.isCurrentUser }
            let order = lhs.user.name.localizedCaseInsensitiveCompare(rhs.user.name)
            return order == .orderedSame ? lhs.user.id < rhs.user.id : order == .orderedAscending
        }
    }
}
