//
//  ChatMessageView.swift
//
//
//  Created by Alisa Mylnikova on 20.03.2023.
//

import SwiftUI

struct ChatMessageView<MessageContent: View>: View {

    typealias MessageBuilderParamsClosure = ChatView<MessageContent, EmptyView, DefaultMessageMenuAction>.MessageBuilderParamsClosure

    @Environment(\.chatTheme) private var theme
    @ObservedObject var viewModel: ChatViewModel

    var messageBuilder: MessageBuilderParamsClosure

    let row: MessageRow
    let chatType: ChatType
    let messageParams: MessageCustomizationParameters
    let isDisplayingMessageMenu: Bool

    @State var timeViewSize: CGSize?

    // isaCloud: pulling the bubble to the right replies to it
    /// how far the bubble is pulled
    @State private var pullOffset: CGFloat = 0
    /// nil until the direction of the drag is known: only a drag that starts going sideways pulls the bubble
    @State private var pullIsHorizontal: Bool?
    @State private var pullPassedThreshold = false
    private let pullThreshold: CGFloat = 64
    private let pullMaximum: CGFloat = 96

    private var canPullToReply: Bool {
        !isDisplayingMessageMenu && viewModel.swipeToReply != nil && viewModel.swipeToReplyActiveFor(row.message)
    }

    var body: some View {
        ZStack {
            let customMessageView = messageBuilder(
                MessageBuilderParameters(
                    message: row.message,
                    positionInGroup: row.positionInUserGroup,
                    positionInMessagesSection: row.positionInMessagesSection,
                    positionInCommentsGroup: row.commentsPosition,
                    showContextMenuClosure: { viewModel.messageMenuRow = row },
                    messageActionClosure: viewModel.messageMenuAction(),
                    showAttachmentClosure: { attachment in
                        self.viewModel.presentAttachmentFullScreen(attachment)
                    },
                    // isaCloud: open the reaction details sheet
                    showReactionDetailsClosure: {
                        self.viewModel.presentReactionDetails(for: row.message.id)
                    }
                )
            )

            if customMessageView is DummyView {
                MessageView(
                    viewModel: viewModel,
                    message: row.message,
                    positionInUserGroup: row.positionInUserGroup,
                    positionInMessagesSection: row.positionInMessagesSection,
                    chatType: chatType,
                    params: messageParams,
                    isDisplayingMessageMenu: isDisplayingMessageMenu
                )
            } else {
                customMessageView
                    .environmentObject(viewModel)
                    .environment(\.chatMessageType, chatType)
                    .environment(\.messageCustomizationParams, messageParams)
            }
        }
        .offset(x: pullOffset)
        .background(alignment: .leading) {
            if pullOffset > 0 {
                pullReplyIcon
            }
        }
        .applyIf(canPullToReply) {
            $0.simultaneousGesture(pullGesture)
        }
        .id(row.message.id)
    }

    /// the arrow that shows up behind the bubble while it is pulled, and fills in when letting go would reply
    private var pullReplyIcon: some View {
        let progress = min(pullOffset / pullThreshold, 1)
        return Image(systemName: "arrowshape.turn.up.left.fill")
            .font(.body)
            .foregroundStyle(pullPassedThreshold ? Color.white : Color.secondary)
            .frame(width: 34, height: 34)
            .background(Circle().fill(pullPassedThreshold ? theme.colors.messageMyBG : Color.secondary.opacity(0.15)))
            .scaleEffect(0.5 + 0.5 * progress)
            .opacity(progress)
            .padding(.leading, 12)
            .accessibilityHidden(true)
    }

    /// the bubble follows the finger, slower after the threshold; letting go replies when it is past the threshold and the
    /// bubble springs back (the bounce)
    private var pullGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if pullIsHorizontal == nil {
                    // a drag that starts going up or down is the list scrolling; a drag from the left edge is the back gesture
                    pullIsHorizontal = value.translation.width > 0
                        && value.translation.width > abs(value.translation.height) * 1.5
                        && value.startLocation.x > 24
                }
                guard pullIsHorizontal == true else { return }
                let width = max(value.translation.width, 0)
                let pulled = width <= pullThreshold ? width : pullThreshold + (width - pullThreshold) * 0.25
                pullOffset = min(pulled, pullMaximum)
                let passed = pullOffset >= pullThreshold
                if passed != pullPassedThreshold {
                    pullPassedThreshold = passed
                    if passed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                }
            }
            .onEnded { _ in
                let shouldReply = pullIsHorizontal == true && pullPassedThreshold
                pullIsHorizontal = nil
                pullPassedThreshold = false
                withAnimation(.interpolatingSpring(stiffness: 260, damping: 11)) {
                    pullOffset = 0
                }
                if shouldReply {
                    viewModel.swipeToReply?(row.message)
                    viewModel.focusTheInputTextView()
                }
            }
    }
}
