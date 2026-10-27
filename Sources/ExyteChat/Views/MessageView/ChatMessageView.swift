//
//  ChatMessageView.swift
//
//
//  Created by Alisa Mylnikova on 20.03.2023.
//

import SwiftUI

struct ChatMessageView<MessageContent: View>: View {

    typealias MessageBuilderParamsClosure = ChatView<MessageContent, EmptyView, DefaultMessageMenuAction>.MessageBuilderParamsClosure

    @ObservedObject var viewModel: ChatViewModel

    var messageBuilder: MessageBuilderParamsClosure

    let row: MessageRow
    let chatType: ChatType
    let messageParams: MessageCustomizationParameters
    let isDisplayingMessageMenu: Bool

    @State var timeViewSize: CGSize?

    // isaCloud: pulling the bubble to the right replies to it; the pull itself lives in PullToReplyContainer, not in a @State
    // or @StateObject of this view: this view builds the whole message, and it would be built again on every frame of the drag

    private var canPullToReply: Bool {
        !isDisplayingMessageMenu && viewModel.swipeToReply != nil && viewModel.swipeToReplyActiveFor(row.message)
    }

    var body: some View {
        PullToReplyContainer(
            enabled: canPullToReply,
            onReply: {
                viewModel.swipeToReply?(row.message)
                viewModel.focusTheInputTextView()
            },
            content: messageContent
        )
        .id(row.message.id)
    }

    @ViewBuilder
    private var messageContent: some View {
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
    }
}

// MARK: - isaCloud: pull to reply

/// The pull of one bubble. A class on its own, read only by PullToReplyContainer: a @State of ChatMessageView would build
/// the whole message (the app's message builder, the bubble) again on every frame of the drag.
private final class PullToReplyState: ObservableObject {
    /// how far the bubble is pulled
    @Published var offset: CGFloat = 0
    @Published var passedThreshold = false
    /// nil until the direction of the drag is known: only a drag that starts going sideways pulls the bubble
    var isHorizontal: Bool?
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    /// a generator that is created and fired at once answers late (the first tap of the vibration motor), so it is prepared before
    func prepareHaptics() { haptics.prepare() }
    func impact() { haptics.impactOccurred() }
}

/// Moves the bubble with the finger and draws the reply arrow behind it. Letting go past the threshold replies, and the bubble
/// springs back (the bounce).
private struct PullToReplyContainer<Content: View>: View {
    @Environment(\.chatTheme) private var theme
    @StateObject private var state = PullToReplyState()
    let enabled: Bool
    let onReply: () -> Void
    let content: Content

    private let threshold: CGFloat = 64
    private let maximum: CGFloat = 96
    private let bounce = Animation.interpolatingSpring(stiffness: 260, damping: 11)

    var body: some View {
        content
            .offset(x: state.offset)
            .background(alignment: .leading) {
                if state.offset > 0 {
                    replyIcon
                }
            }
            .modifier(PullGestureModifier(enabled: enabled, onChanged: pullChanged, onEnded: pullEnded, fallback: gesture))
    }

    /// the arrow that shows up behind the bubble while it is pulled, and fills in when letting go would reply
    private var replyIcon: some View {
        let progress = min(state.offset / threshold, 1)
        return Image(systemName: "arrowshape.turn.up.left.fill")
            .font(.body)
            .foregroundStyle(state.passedThreshold ? Color.white : Color.secondary)
            .frame(width: 34, height: 34)
            .background(Circle().fill(state.passedThreshold ? theme.colors.messageMyBG : Color.secondary.opacity(0.15)))
            .scaleEffect(0.5 + 0.5 * progress)
            .opacity(progress)
            .padding(.leading, 12)
            .accessibilityHidden(true)
    }

    /// the bubble follows the finger, slower after the threshold
    private func pullChanged(width rawWidth: CGFloat) {
        if state.isHorizontal == nil {
            state.isHorizontal = true
            state.prepareHaptics()
        }
        let width = max(rawWidth, 0)
        let pulled = width <= threshold ? width : threshold + (width - threshold) * 0.25
        state.offset = min(pulled, maximum)
        let passed = state.offset >= threshold
        if passed != state.passedThreshold {
            state.passedThreshold = passed
            if passed { state.impact() }
        }
    }

    private func pullEnded() {
        let shouldReply = state.isHorizontal == true && state.passedThreshold
        state.isHorizontal = nil
        state.passedThreshold = false
        withAnimation(bounce) {
            state.offset = 0
        }
        if shouldReply {
            // the keyboard and the quote in the text field come after the bounce, not together with it: both are heavy
            // for the main thread and made the bounce stutter
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onReply()
            }
        }
    }

    /// iOS 17 only (the minimum of the library): the SwiftUI drag
    private var gesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if state.isHorizontal == nil {
                    // a drag that starts going up or down is the list scrolling; a drag from the left edge is the back gesture
                    state.isHorizontal = value.translation.width > 0
                        && value.translation.width > abs(value.translation.height) * 1.5
                        && value.startLocation.x > 24
                    if state.isHorizontal == true {
                        state.prepareHaptics()
                    }
                }
                guard state.isHorizontal == true else { return }
                pullChanged(width: value.translation.width)
            }
            .onEnded { _ in pullEnded() }
    }
}

/// isaCloud: from iOS 18 the pull is a UIKit pan that only begins sideways, so a drag up or down on the bubble reaches the list
/// (the SwiftUI DragGesture made the list stop scrolling when the drag started on a bubble). iOS 17 keeps the SwiftUI drag.
private struct PullGestureModifier<Fallback: Gesture>: ViewModifier {
    let enabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let fallback: Fallback

    @ViewBuilder
    func body(content: Content) -> some View {
        if !enabled {
            content
        } else if #available(iOS 18.0, *) {
            content.gesture(SidewaysPanGesture(onChanged: onChanged, onEnded: onEnded))
        } else {
            content.simultaneousGesture(fallback)
        }
    }
}

/// A pan that only begins when the finger goes to the right: anything else (a drag up or down, which is the list scrolling, or a
/// drag from the left edge, which is the back gesture) never starts it, so the list gets the touch.
@available(iOS 18.0, *)
private struct SidewaysPanGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // the window is the space of the translation: the bubble moves with the finger, and so would its own space
        switch recognizer.state {
        case .began, .changed:
            onChanged(recognizer.translation(in: nil).x)
        case .ended, .cancelled, .failed:
            onEnded()
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: nil)
            let startX = pan.location(in: nil).x - pan.translation(in: nil).x
            return velocity.x > 0 && velocity.x > abs(velocity.y) * 1.5 && startX > 24
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }

        /// From iOS 26 the navigation controller also has a back swipe that works anywhere on the screen: it waits for this pan to fail,
        /// so a pull on a bubble replies and does not also go back
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy other: UIGestureRecognizer
        ) -> Bool {
            guard #available(iOS 26.0, *) else { return false }
            var responder: UIResponder? = gestureRecognizer.view
            while let current = responder {
                if let navigation = current as? UINavigationController {
                    return navigation.interactiveContentPopGestureRecognizer === other
                }
                responder = current.next
            }
            return false
        }
    }
}
