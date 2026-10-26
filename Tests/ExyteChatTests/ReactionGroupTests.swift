//
//  ReactionGroupTests.swift
//  isaCloud: tests of the reactions grouped by emoji
//  Chat
//

import Foundation
import Testing

@testable import ExyteChat

struct ReactionGroupTests {

    let me = User(id: "me", name: "Me", avatarURL: nil, isCurrentUser: true)
    let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)
    let stan = User(id: "stan", name: "Stan", avatarURL: nil, isCurrentUser: false)

    let now = Date(timeIntervalSince1970: 1_000_000)

    private func reaction(_ user: User, _ emoji: String, secondsAgo: TimeInterval) -> Reaction {
        Reaction(user: user, createdAt: now.addingTimeInterval(-secondsAgo), type: .emoji(emoji), status: .sent)
    }

    @Test func noReactionsGiveNoGroups() {
        #expect(ReactionGroup.groups(of: []).isEmpty)
    }

    @Test func twoPeopleWithTheSameEmojiAreOneGroup() {
        let groups = ReactionGroup.groups(of: [
            reaction(me, "❤️", secondsAgo: 60),
            reaction(sally, "❤️", secondsAgo: 30),
        ])

        #expect(groups.count == 1)
        #expect(groups[0].emoji == "❤️")
        #expect(groups[0].count == 2)
        #expect(groups[0].users.map(\.id) == ["sally", "me"], "newest first")
    }

    @Test func differentEmojisAreDifferentGroups() {
        let groups = ReactionGroup.groups(of: [
            reaction(me, "❤️", secondsAgo: 60),
            reaction(sally, "🤣", secondsAgo: 30),
        ])

        #expect(groups.map(\.emoji) == ["🤣", "❤️"])
        #expect(groups.map(\.count) == [1, 1])
    }

    @Test func groupsAreOrderedByTheirNewestReaction() {
        let groups = ReactionGroup.groups(of: [
            reaction(me, "🔥", secondsAgo: 100),
            reaction(sally, "🥳", secondsAgo: 50),
            reaction(stan, "🔥", secondsAgo: 10),
        ])

        // 🔥 has the newest reaction (stan, 10 s ago), so it comes first although it was also the oldest
        #expect(groups.map(\.emoji) == ["🔥", "🥳"])
        #expect(groups[0].latest == now.addingTimeInterval(-10))
    }

    @Test func reactionsWithTheSameTimeKeepAStableOrder() {
        let reactions = [
            reaction(me, "🧠", secondsAgo: 5),
            reaction(sally, "🔥", secondsAgo: 5),
            reaction(stan, "🥳", secondsAgo: 5),
        ]

        let first = ReactionGroup.groups(of: reactions).map(\.emoji)
        let second = ReactionGroup.groups(of: reactions.reversed()).map(\.emoji)

        #expect(first == second)
    }

    @Test func currentUserIsDetectedInAGroup() {
        let groups = ReactionGroup.groups(of: [
            reaction(sally, "❤️", secondsAgo: 30),
            reaction(me, "❤️", secondsAgo: 60),
            reaction(sally, "🤣", secondsAgo: 10),
        ])

        let heart = groups.first { $0.emoji == "❤️" }
        let laugh = groups.first { $0.emoji == "🤣" }
        #expect(heart?.containsCurrentUser == true)
        #expect(laugh?.containsCurrentUser == false)
    }

    @Test func theCurrentUsersReactionRepresentsTheGroup() {
        let groups = ReactionGroup.groups(of: [
            reaction(sally, "❤️", secondsAgo: 10),
            reaction(me, "❤️", secondsAgo: 60),
        ])

        #expect(groups[0].representative.user.isCurrentUser)
    }

    @Test func withoutTheCurrentUserTheNewestReactionRepresentsTheGroup() {
        let groups = ReactionGroup.groups(of: [
            reaction(stan, "❤️", secondsAgo: 60),
            reaction(sally, "❤️", secondsAgo: 10),
        ])

        #expect(groups[0].representative.user.id == "sally")
    }
}

struct PersonReactionsTests {

    let me = User(id: "me", name: "Me", avatarURL: nil, isCurrentUser: true)
    let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)
    let stan = User(id: "stan", name: "Stan", avatarURL: nil, isCurrentUser: false)

    let now = Date(timeIntervalSince1970: 1_000_000)

    private func reaction(_ user: User, _ emoji: String, secondsAgo: TimeInterval) -> Reaction {
        Reaction(user: user, createdAt: now.addingTimeInterval(-secondsAgo), type: .emoji(emoji), status: .sent)
    }

    @Test func onePersonWithTwoEmojisIsOneLine() {
        let people = PersonReactions.people(of: [
            reaction(sally, "❤️", secondsAgo: 10),
            reaction(sally, "🤣", secondsAgo: 10),
            reaction(stan, "🤣", secondsAgo: 20),
        ])

        #expect(people.map(\.user.id) == ["sally", "stan"])
        #expect(people[0].emojis == ["🤣", "❤️"], "same time: the last one given is the newest")
    }

    @Test func theCurrentUserIsAlwaysFirst() {
        let people = PersonReactions.people(of: [
            reaction(sally, "❤️", secondsAgo: 1),
            reaction(me, "🔥", secondsAgo: 500),
        ])

        #expect(people.map(\.user.id) == ["me", "sally"])
    }

    @Test func othersAreInAlphabeticalOrder() {
        let people = PersonReactions.people(of: [
            reaction(stan, "❤️", secondsAgo: 5),
            reaction(sally, "❤️", secondsAgo: 50),
        ])

        #expect(people.map(\.user.id) == ["sally", "stan"], "by name, not by time")
    }
}
