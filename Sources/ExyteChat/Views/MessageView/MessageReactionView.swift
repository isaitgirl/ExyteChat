//
//  MessageView+Reaction.swift
//  Chat
//

import SwiftUI

extension MessageView {
    
    @ViewBuilder
    func reactionsView(_ message: Message, maxReactions: Int = 5) -> some View {
        // isaCloud: one bubble per emoji (with a count), not one per reaction
        let groups = ReactionGroup.groups(of: message.reactions)
        let preparedReactions = prepareReactions(groups: groups, message: message, maxReactions: maxReactions)
        let overflowBubbleText = "+\(groups.count - maxReactions + 1)"
        
        HStack(spacing: -reactionViewWidth / 5) {
            if !message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: true,
                    needsOverflowBubble: preparedReactions.needsOverflowBubble,
                    text: overflowBubbleText,
                    containsReactionFromCurrentUser: preparedReactions.overflowContainsCurrentUser
                )
            }
            
            ForEach(Array(preparedReactions.groups.enumerated()), id: \.element.id) { index, group in
                ReactionBubble(reaction: group.representative, count: group.count, font: params.font)
                    .transition(.scaleAndFade)
                    .zIndex(message.user.isCurrentUser ? Double(preparedReactions.groups.count - index) : Double(index + 1))
            }
            
            if message.user.isCurrentUser {
                overflowBubbleView(
                    leadingSpacer: false,
                    needsOverflowBubble: preparedReactions.needsOverflowBubble,
                    text: overflowBubbleText,
                    containsReactionFromCurrentUser: preparedReactions.overflowContainsCurrentUser
                )
            }
        }
        .offset(
            x: message.user.isCurrentUser ? -(reactionViewWidth / 2) : (reactionViewWidth / 2),
            y: 0
        )
        // isaCloud: a tap on the reactions shows who reacted with what
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.presentReactionDetails(for: message.id)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: groups.map { "\($0.emoji) \($0.count)" }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }
    
    @ViewBuilder
    func overflowBubbleView(leadingSpacer: Bool, needsOverflowBubble: Bool, text: String, containsReactionFromCurrentUser: Bool) -> some View {
        if needsOverflowBubble {
            ReactionBubble(
                reaction: .init(
                    user: .init(
                        id: "null",
                        name: "",
                        avatarURL: nil,
                        isCurrentUser: containsReactionFromCurrentUser
                    ),
                    type: .emoji(text),
                    status: .sent
                ),
                font: params.font
            )
            .padding(message.user.isCurrentUser ? .trailing : .leading, -3)
        }
    }
    
    struct PreparedReactions {
        /// Reaction groups sorted by most recent -> oldest (trimmed to maxReactions)
        let groups: [ReactionGroup]
        /// Indicates whether we need to add an overflow bubble (due to the number of groups exceeding maxReactions)
        let needsOverflowBubble: Bool
        /// Indicates whether the clipped groups (oldest groups beyond maxReaction) contain a reaction from the current user
        /// - Note: This value is used to color the background of the overflow bubble
        let overflowContainsCurrentUser: Bool
    }
    
    /// Orders the groups by most recent to oldest, reverses their layout based on alignment and determines if an overflow bubble is necessary
    private func prepareReactions(groups allGroups: [ReactionGroup], message: Message, maxReactions: Int) -> PreparedReactions {
        guard maxReactions > 1, !allGroups.isEmpty else {
            return .init(groups: [], needsOverflowBubble: false, overflowContainsCurrentUser: false)
        }
        // If we have more groups than maxReactions, then we'll need an overflow bubble
        let needsOverflowBubble = allGroups.count > maxReactions
        // `ReactionGroup.groups(of:)` already sorts the groups by most recent -> oldest
        var groups = allGroups
        // Check if our current user has a reaction in the overflow groups (used for coloring the overflow bubble)
        var overflowContainsCurrentUser: Bool = false
        if needsOverflowBubble {
            overflowContainsCurrentUser = groups[(maxReactions - 1)...].contains(where: { $0.containsCurrentUser })
        }
        // Trim the groups array if necessary
        if needsOverflowBubble { groups = Array(groups.prefix(maxReactions - 1)) }
        
        return .init(
            groups: message.user.isCurrentUser ? groups : groups.reversed(),
            needsOverflowBubble: needsOverflowBubble,
            overflowContainsCurrentUser: overflowContainsCurrentUser
        )
    }
}

struct ReactionBubble: View {
    
    @Environment(\.chatTheme) var theme
    
    let reaction: Reaction
    /// how many people reacted with this emoji; a small badge with the count sits on the bubble when more than one
    var count: Int = 1
    let font: UIFont

    static let padding: CGFloat = 6

    @State private var phase = 0.0
    
    var fillColor: Color {
        switch reaction.status {
        case .sending, .sent, .read:
            return reaction.user.isCurrentUser ? theme.colors.messageMyBG : theme.colors.messageFriendBG
        case .error:
            return .red
        }
    }
    
    var opacity: Double {
        switch reaction.status {
        case .sent, .read:
            return 1.0
        case .sending, .error:
            return 0.7
        }
    }
    
    var body: some View {
        Text(reaction.emoji ?? "?")
            .font(Font(font))
            .opacity(opacity)
            .foregroundStyle(theme.colors.messageText(reaction.user.type))
            .padding(ReactionBubble.padding)
            .background(
                ZStack {
                    Circle()
                        .fill(fillColor)
                    // If the reaction is in flight, animate the stroke
                    if reaction.status == .sending {
                        Circle()
                            .stroke(style: .init(lineWidth: 2, lineCap: .round, dash: [100, 50], dashPhase: phase))
                            .fill(theme.colors.messageFriendBG)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                                    phase -= 150
                                }
                            }
                    // Otherwise just stroke the circle normally
                    } else {
                        Circle()
                            .stroke(style: .init(lineWidth: 2))
                            .fill(theme.colors.mainBG)
                    }
                }
            )
            // isaCloud: the count sits on the top corner, so it does not cover the neighbour bubble or the message text
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text(verbatim: "\(count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.colors.mainBG)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Circle().fill(theme.colors.mainText))
                        .offset(x: 4, y: -4)
                }
            }
    }
}
