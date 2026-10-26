//
//  EmojiKeyboardField.swift
//  isaCloud: new file (the system emoji keyboard to pick an emoji to react with)
//  Chat
//

import SwiftUI
import UIKit

/// An invisible text field that brings up the system emoji keyboard while `isActive` is true. Every emoji typed goes
/// to `onEmoji` and the keyboard goes away.
struct EmojiKeyboardField: UIViewRepresentable {

    @Binding var isActive: Bool
    let onEmoji: (String) -> Void

    final class Field: UITextField {
        // asks the system for the emoji keyboard instead of the one of the last used language
        override var textInputMode: UITextInputMode? {
            UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.autocorrectionType = .no
        field.alpha = 0.01
        field.isAccessibilityElement = false
        return field
    }

    func updateUIView(_ field: Field, context: Context) {
        context.coordinator.parent = self
        if isActive, !field.isFirstResponder {
            DispatchQueue.main.async { field.becomeFirstResponder() }
        } else if !isActive, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiKeyboardField

        init(_ parent: EmojiKeyboardField) {
            self.parent = parent
        }

        @objc func textChanged(_ field: UITextField) {
            guard let emoji = field.text?.last(where: { $0.isEmojiCharacter }) else { return }
            field.text = ""
            parent.onEmoji(String(emoji))
            parent.isActive = false
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            parent.isActive = false
        }
    }
}

private extension Character {
    /// emoji, not the digits and symbols that are only emoji when followed by a variation selector
    var isEmojiCharacter: Bool {
        guard let first = unicodeScalars.first else { return false }
        return first.properties.isEmojiPresentation || (first.properties.isEmoji && first.value > 0xFF)
            || (unicodeScalars.count > 1 && first.properties.isEmoji)
    }
}
