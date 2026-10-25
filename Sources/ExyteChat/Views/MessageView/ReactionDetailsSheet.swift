//
//  ReactionDetailsSheet.swift
//  isaCloud: new file (reactions grouped by emoji / who reacted with what)
//  Chat
//

import SwiftUI

/// A sheet that lists who reacted to a message and with which emoji. Shown when the reactions of a message are tapped.
struct ReactionDetailsSheet: View {

    @Environment(\.chatTheme) private var theme

    /// nil when the message is not there anymore
    let message: Message?
    let localization: ChatLocalization

    /// the emoji the list is filtered by, nil for all of them
    @State private var selectedEmoji: String?

    private let avatarSize: CGFloat = 40

    private var groups: [ReactionGroup] {
        ReactionGroup.groups(of: message?.reactions ?? [])
    }

    private var totalCount: Int {
        groups.reduce(0) { $0 + $1.count }
    }

    /// the reactions shown in the list, newest first, filtered by the selected emoji
    private var visibleReactions: [Reaction] {
        let selected = groups.first { $0.emoji == selectedEmoji }
        let reactions = selected.map(\.reactions) ?? groups.flatMap(\.reactions)
        return reactions.sorted { $0.createdAt > $1.createdAt }
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
                    ForEach(visibleReactions, id: \.rowId) { reaction in
                        row(for: reaction)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(theme.colors.mainBG)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // the selected emoji can disappear while the sheet is open (somebody removed the reaction)
        .onChange(of: groups.map(\.emoji)) { _, emojis in
            if let selectedEmoji, !emojis.contains(selectedEmoji) {
                self.selectedEmoji = nil
            }
        }
    }

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

    private func row(for reaction: Reaction) -> some View {
        HStack(spacing: 12) {
            avatar(for: reaction.user)

            Text(reaction.user.isCurrentUser ? localization.reactionsYouText : reaction.user.name)
                .font(.body)
                .foregroundStyle(theme.colors.mainText)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(reaction.emoji ?? "?")
                .font(.title2)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func avatar(for user: User) -> some View {
        if user.avatarURL != nil || user.avatarImage != nil {
            AvatarImageView(user: user, avatarSize: avatarSize, avatarCacheKey: user.avatarCacheKey)
        } else {
            AvatarNameView(name: user.name, avatarSize: avatarSize)
        }
    }
}

private extension Reaction {
    /// a stable identity for list rows: `Reaction.id` is a new UUID whenever the reactions are rebuilt from the app's data
    var rowId: String { "\(user.id)|\(emoji ?? "")" }
}

#if swift(>=6.0)
    #Preview("Two people, same emoji") {
        let john = User(id: "john", name: "John", avatarURL: nil, isCurrentUser: true)
        let sally = User(id: "sally", name: "Sally", avatarURL: nil, isCurrentUser: false)

        ReactionDetailsSheet(
            message: .init(
                id: UUID().uuidString,
                user: sally,
                status: .read,
                text: "An example message",
                reactions: [
                    Reaction(user: john, createdAt: .now.addingTimeInterval(-60), type: .emoji("❤️"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("❤️"), status: .sent),
                ]
            ),
            localization: .defaultLocalization
        )
    }

    #Preview("Several emojis") {
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
                    Reaction(user: john, createdAt: .now.addingTimeInterval(-50), type: .emoji("🔥"), status: .sent),
                    Reaction(user: stan, createdAt: .now.addingTimeInterval(-40), type: .emoji("🥳"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-30), type: .emoji("🥳"), status: .sent),
                    Reaction(user: sally, createdAt: .now.addingTimeInterval(-20), type: .emoji("🧠"), status: .sent),
                ]
            ),
            localization: .defaultLocalization
        )
    }
#endif
