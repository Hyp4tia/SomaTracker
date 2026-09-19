//
//  SomaComposerField.swift
//  SomaTracker
//
//  The composer's text field, and the reason it is UIKit rather than a SwiftUI TextField.
//
//  SwiftUI's TextField resigns first responder when the keyboard's return key fires `onSubmit`. So the
//  keyboard dropped on every message sent with the return key, which is how this app is used: Pressing
//  Send in the UI was never the problem, the return key always was. Re-assigning focus afterwards
//  produced a visible hide-then-show, and removing that re-assignment left the keyboard down for good.
//
//  `textFieldShouldReturn` returning false is the documented way to say "handle this and stay first
//  responder", and only UIKit offers it. That, and nothing else, is why this file exists.
//

import SwiftUI
import UIKit

struct SomaComposerField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    /// The surface's intent: true while the conversation is open and no camera or recording owns the
    /// screen. The field becomes first responder on its own whenever this is true, and stands down when
    /// it is false, so the keyboard follows the conversation rather than the other way around.
    var wantsFocus: Bool
    var onSend: () -> Void
    /// Keeps the intent honest when the user focuses or leaves the field by touching it.
    var onFocusChange: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.returnKeyType = .send
        field.font = .systemFont(ofSize: 15)
        field.placeholder = placeholder
        field.tintColor = UIColor(SomaColors.navy)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self

        if field.text != text {
            field.text = text
        }
        if field.placeholder != placeholder {
            field.placeholder = placeholder
        }

        // Deferred by one turn so it never fights a presentation or dismissal transition.
        if wantsFocus, !field.isFirstResponder {
            DispatchQueue.main.async {
                guard self.wantsFocus, field.window != nil, !field.isFirstResponder else { return }
                field.becomeFirstResponder()
            }
        } else if !wantsFocus, field.isFirstResponder {
            field.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SomaComposerField

        init(parent: SomaComposerField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        /// Returning false is the whole point: the send happens and the field stays first responder, so
        /// the keyboard does not move.
        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSend()
            return false
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ field: UITextField) {
            #if DEBUG
            // If the keyboard ever drops again, this line says exactly when it did, so the next round is
            // a diagnosis rather than another guess.
            print("[SomaChat] Composer field ended editing at \(Date().formatted(date: .omitted, time: .standard))")
            #endif
            parent.onFocusChange(false)
        }
    }
}
