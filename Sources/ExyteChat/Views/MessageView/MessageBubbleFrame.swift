//
//  MessageBubbleFrame.swift
//
//  isaCloud: the frame of the bubble of a message (quote, bubble, time below the media), read by the long press of UIList:
//  the message menu opens only when the touch is on a bubble, not on the empty space beside it. Kept apart from
//  MessageMenuPreferenceKey, which is the frame of the whole row.
//

import SwiftUI

struct MessageBubbleFrameKey: PreferenceKey {
    static let defaultValue: CGRect? = nil

    /// the smallest frame wins: the bubble measured inside MessageView, not the whole content around a custom builder
    static func reduce(value: inout CGRect?, nextValue: () -> CGRect?) {
        guard let next = nextValue() else { return }
        if let current = value, current.width * current.height <= next.width * next.height {
            return
        }
        value = next
    }
}

extension View {
    /// isaCloud: reports the frame of this view as the bubble of the message (see MessageBubbleFrameKey)
    func reportsMessageBubbleFrame() -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: MessageBubbleFrameKey.self, value: proxy.frame(in: .global))
            }
        )
    }
}
