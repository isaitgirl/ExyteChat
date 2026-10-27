//
//  MessageView+Reaction.swift
//  Chat
//

import SwiftUI

extension MessageView {
    
    /// isaCloud: the reactions of the message as a row of native bordered capsule buttons, for the footer of the bubble.
    /// Tapping any of them shows who reacted with what.
    @ViewBuilder
    func reactionsFooterView(_ message: Message, maxReactions: Int = 5) -> some View {
        let groups = ReactionGroup.groups(of: message.reactions)
        let shown = Array(groups.prefix(maxReactions))
        let hidden = groups.count - shown.count
        HStack(spacing: 6) {
            ForEach(shown) { group in
                reactionCapsule(
                    group.count > 1 ? "\(group.emoji) \(group.count)" : group.emoji,
                    in: message,
                    isMine: group.containsCurrentUser
                )
            }
            if hidden > 0 {
                // the reactions that did not fit: one more capsule, it opens the same sheet
                reactionCapsule("+\(hidden)", in: message, isMine: false)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: groups.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }

    /// one capsule of the footer: solid white on my pink bubbles, so it can be seen; gray on the others, pink for my own
    @ViewBuilder
    private func reactionCapsule(_ text: String, in message: Message, isMine: Bool) -> some View {
        let button = Button {
            viewModel.presentReactionDetails(for: message.id)
        } label: {
            Text(verbatim: text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(message.user.isCurrentUser ? theme.colors.messageMyBG : theme.colors.mainText)
                .lineLimit(1)
                .fixedSize()
        }
        .buttonBorderShape(.capsule)
        .controlSize(.mini)
        if message.user.isCurrentUser {
            button.buttonStyle(.borderedProminent).tint(.white)
        } else {
            button.buttonStyle(.bordered).tint(isMine ? theme.colors.messageMyBG : theme.colors.mainText)
        }
    }
}
