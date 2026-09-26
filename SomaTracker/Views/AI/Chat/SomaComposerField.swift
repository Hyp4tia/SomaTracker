import SwiftUI
import UIKit

struct SomaComposerField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let wantsFocus: Bool
    let onSend: () -> Void
    let onFocusChange: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        // .default is the plain "return" key. .send draws the send arrow, which reads as a
        // second send button next to the one in the composer.
        field.returnKeyType = .default
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.placeholder = placeholder
        field.tintColor = UIColor(SomaColors.navy)
        // A text field's intrinsic width is the width of its text or placeholder, which is wider
        // than what is left of the composer row. Without these the field wins that fight and pushes
        // the pill past both screen edges.
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    /// The field takes whatever width the row gives it and asks only for the row's height. Returning
    /// the intrinsic width here is what made the composer wider than the screen.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        let height = max(uiView.intrinsicContentSize.height, 34)
        guard let width = proposal.width, width > 0 else {
            return CGSize(width: uiView.intrinsicContentSize.width, height: height)
        }
        return CGSize(width: width, height: height)
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        if field.placeholder != placeholder { field.placeholder = placeholder }

        if wantsFocus, !field.isFirstResponder {
            DispatchQueue.main.async {
                guard wantsFocus, field.window != nil else { return }
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

        @objc func changed(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSend()
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onFocusChange(true)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.onFocusChange(false)
        }
    }
}
