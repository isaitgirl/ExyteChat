//
//  ReactionDetailsSheet.swift
//  isaCloud: new file (reactions grouped by emoji / who reacted with what / react from the sheet)
//  Chat
//

import Combine
import SwiftUI

/// Passes on the changes of a message (the app changes it in place when a reaction arrives), so the sheet shows them.
private final class ObservedMessage: ObservableObject {
    private var subscription: AnyCancellable?

    func observe(_ message: Message?) {
        subscription = message?.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.objectWillChange.send() }
        }
    }
}

/// A sheet that lists who reacted to a message and with which emojis, one line per person, and lets the current user
/// add or remove their own reactions. Shown when the reactions of a message are tapped.
struct ReactionDetailsSheet: View {

    @Environment(\.chatTheme) private var theme

    /// nil when the message is not there anymore
    let message: Message?
    let localization: ChatLocalization

    /// the current user, for the avatar of their line while they have not reacted
    var currentUser: User? = nil
    /// whether the current user can react to this message; the strip of emojis to react with is hidden otherwise
    var canReact: Bool = false
    /// adds or removes the reaction of the current user with this emoji
    var onReact: (String) -> Void = { _ in }

    /// the system emoji keyboard is up, to pick an emoji to react with
    @State private var pickingEmoji = false

    @StateObject private var observedMessage = ObservedMessage()

    /// the emoji the list is filtered by, nil for all of them
    @State private var selectedEmoji: String?

    private let avatarSize: CGFloat = 40
    private let nameWidth: CGFloat = 92

    private var reactions: [Reaction] {
        message?.reactions ?? []
    }

    private var groups: [ReactionGroup] {
        ReactionGroup.groups(of: reactions)
    }

    private var totalCount: Int {
        groups.reduce(0) { $0 + $1.count }
    }

    /// everybody who reacted, the current user first
    private var people: [PersonReactions] {
        PersonReactions.people(of: reactions)
    }

    /// the lines of the list: all the people, or only the ones who used the selected emoji
    private var visiblePeople: [PersonReactions] {
        guard let selectedEmoji else { return people }
        return people.filter { $0.emojis.contains(selectedEmoji) }
    }

    /// the reactions of the current user, nil while they have not reacted
    private var myPerson: PersonReactions? {
        people.first { $0.user.isCurrentUser }
    }

    private var title: String {
        totalCount == 1
            ? localization.reactionsTitleOneText
            : String(format: localization.reactionsTitleFormat, totalCount)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .padding(.top, 24)
                .padding(.bottom, 12)

            if groups.count > 1 {
                filterChips
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    // the line of the current user is always the first one, even when they have not reacted
                    myRow
                    ForEach(visiblePeople.filter { !$0.user.isCurrentUser }) { person in
                        row(for: person)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colors.mainBG)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { observedMessage.observe(message) }
        .onChange(of: message?.id) { _, _ in observedMessage.observe(message) }
        // the selected emoji can disappear while the sheet is open (somebody removed the reaction)
        .onChange(of: groups.map(\.emoji)) { _, emojis in
            if let selectedEmoji, !emojis.contains(selectedEmoji) {
                self.selectedEmoji = nil
            }
        }
    }

    // MARK: - filter

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(text: "\(localization.allReactionsText) \(totalCount)", isSelected: selectedEmoji == nil) {
                    selectedEmoji = nil
                }
                ForEach(groups) { group in
                    chip(text: "\(group.emoji) \(group.count)", isSelected: selectedEmoji == group.emoji) {
                        selectedEmoji = group.emoji
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(text: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.colors.mainText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? theme.colors.messageMyBG.opacity(0.25) : Color.clear)
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? theme.colors.messageMyBG : theme.colors.mainText.opacity(0.25),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - list

    private func name(of user: User) -> String {
        user.isCurrentUser ? localization.reactionsYouText : user.name
    }

    private func row(for person: PersonReactions) -> some View {
        HStack(spacing: 10) {
            avatar(for: person.user)

            Text(name(of: person.user))
                .font(.body)
                .foregroundStyle(theme.colors.mainText)
                .lineLimit(1)
                .frame(width: nameWidth, alignment: .leading)

            emojiStrip(person.emojis)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(name(of: person.user)): \(person.emojis.joined(separator: ", "))"))
    }

    /// The line of the current user, always the first one: a "+" opens the system emoji keyboard to add a reaction,
    /// and each emoji they already gave is a button that takes it back.
    private var myRow: some View {
        HStack(spacing: 10) {
            if let currentUser {
                avatar(for: currentUser)
            } else {
                letterAvatar(localization.reactionsYouText)
            }

            Text(localization.reactionsYouText)
                .font(.body)
                .foregroundStyle(theme.colors.mainText)
                .lineLimit(1)
                .frame(width: nameWidth, alignment: .leading)

            if canReact {
                emojiStrip(myPerson?.emojis ?? [], tappable: true)
            } else {
                emojiStrip(myPerson?.emojis ?? [])
            }
        }
        .padding(.vertical, 8)
        .background(EmojiKeyboardField(isActive: $pickingEmoji) { emoji in
            onReact(emoji)
        })
    }

    /// The emojis of a person: on the right when they fit, in a strip that scrolls sideways when they do not.
    private func emojiStrip(_ emojis: [String], tappable: Bool = false) -> some View {
        ViewThatFits(in: .horizontal) {
            emojiRow(emojis, tappable: tappable)
                .frame(maxWidth: .infinity, alignment: .trailing)

            ScrollView(.horizontal) {
                emojiRow(emojis, tappable: tappable)
                    .padding(.trailing, 16)
            }
            .scrollIndicators(.hidden)
            // fades the right edge: there is more to scroll to
            .mask(
                LinearGradient(
                    stops: [.init(color: .black, location: 0.82), .init(color: .clear, location: 1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var plusButton: some View {
        Button {
            pickingEmoji = true
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.colors.messageMyBG)
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(theme.colors.messageMyBG, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])))
        }
        .buttonStyle(.plain)
    }

    /// - Parameter tappable: the emojis are buttons that take the reaction back (the line of the current user)
    private func emojiRow(_ emojis: [String], tappable: Bool) -> some View {
        HStack(spacing: 6) {
            if tappable {
                plusButton
            }
            ForEach(Array(emojis.enumerated()), id: \.offset) { _, emoji in
                // while filtering, the emoji that was picked stands out in every line
                let highlighted = emoji == selectedEmoji
                if tappable {
                    Button {
                        onReact(emoji)
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(theme.colors.messageMyBG.opacity(highlighted ? 0.3 : 0.15)))
                            .overlay(Circle().stroke(theme.colors.messageMyBG, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(emoji))
                } else {
                    Text(emoji)
                        .font(.title2)
                        .padding(4)
                        .background(Circle().fill(highlighted ? theme.colors.messageMyBG.opacity(0.25) : Color.clear))
                }
            }
        }
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if user.avatarURL != nil || user.avatarImage != nil {
            AvatarImageView(user: user, avatarSize: avatarSize, avatarCacheKey: user.avatarCacheKey)
        } else {
            letterAvatar(user.name)
        }
    }

    /// the first letter on a circle, for who has no picture (AvatarNameView has no background of its own)
    private func letterAvatar(_ name: String) -> some View {
        AvatarNameView(name: name, avatarSize: avatarSize)
            .foregroundStyle(theme.colors.mainText)
            .background(Circle().fill(theme.colors.mainText.opacity(0.15)))
    }
}

#if swift(>=6.0)
    #Preview("One line per person, react from the sheet") {
        let john = User(id: "john", name: "John", avatarURL: nil, isCurrentUser: true)
        let stan = User(id: "stan", name: "Stan", avatarURL: nil, isCurrentUser: false)
        let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)

        ReactionDetailsSheet(
            message: .init(
                id: UUID().uuidString,
                user: stan,
                status: .read,
                text: "An example message",
                reactions: [
                    Reaction(user: john, createdAt: .now.addingTimeInterval(-60), type: .emoji("🔥"), status: .sent),
                    Reaction(user: john, createdAt: .now.addingTimeInterval(-60), type: .emoji("❤️"), status: .sent),
                    Reaction(user: stan, createdAt: .now.addingTimeInterval(-40), type: .emoji("🥳"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("🥳"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("🧠"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("👏"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("🎉"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("😮"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("😢"), status: .sent),
                ]
            ),
            localization: .defaultLocalization,
            currentUser: john,
            canReact: true
        )
    }

    #Preview("The current user has not reacted") {
        let john = User(id: "john", name: "John", avatarURL: nil, isCurrentUser: true)
        let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)

        ReactionDetailsSheet(
            message: .init(
                id: UUID().uuidString,
                user: sally,
                status: .read,
                text: "An example message",
                reactions: [
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("❤️"), status: .sent),
                ]
            ),
            localization: .defaultLocalization,
            currentUser: john,
            canReact: true
        )
    }
#endif
