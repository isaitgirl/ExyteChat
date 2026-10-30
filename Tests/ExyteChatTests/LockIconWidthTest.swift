//
//  LockIconWidthTest.swift
//  Chat
//

import SwiftUI
import Testing
import UIKit

@testable import ExyteChat

// isaCloud: the lock drawn before the time of an encrypted message takes room in the bubble (see MessageView.timeViewArrangement)
struct LockIconWidthTest {

    @Test("The lock icon takes some width")
    func lockIconTakesWidth() {
        let width = MessageView.lockIconWidth(font: UIFont.systemFont(ofSize: 10))
        #expect(width > 0)
    }

    @Test("The lock icon grows with the time font")
    func lockIconGrowsWithFont() {
        let small = MessageView.lockIconWidth(font: UIFont.systemFont(ofSize: 10))
        let large = MessageView.lockIconWidth(font: UIFont.systemFont(ofSize: 20))
        #expect(large > small)
    }
}
