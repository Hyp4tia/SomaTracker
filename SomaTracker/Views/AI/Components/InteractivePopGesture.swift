//
//  InteractivePopGesture.swift
//  SomaTracker
//
//  Restores native iOS interactive edge swipe-to-go-back when navigationBarBackButtonHidden is true.
//

import UIKit
import SwiftUI

// 1. Global UINavigationController delegate override
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return viewControllers.count > 1
    }
}

private class PopGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    weak var targetNavController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = targetNavController else { return true }
        return nav.viewControllers.count > 1
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

// 2. Direct Responder Chain view helper to actively hook into the active UINavigationController
private class PopGestureEnablingView: UIView {
    private let coordinator = PopGestureCoordinator()

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachGesture()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachGesture()
    }

    private func attachGesture() {
        guard let nav = findNavigationController() else { return }
        coordinator.targetNavController = nav
        nav.interactivePopGestureRecognizer?.isEnabled = true
        nav.interactivePopGestureRecognizer?.delegate = coordinator
    }

    private func findNavigationController() -> UINavigationController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let nav = next as? UINavigationController {
                return nav
            }
            if let vc = next as? UIViewController, let nav = vc.navigationController {
                return nav
            }
            responder = next
        }
        return nil
    }
}

public struct NativeSwipeToGoBack: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> UIView {
        let view = PopGestureEnablingView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}

public extension View {
    func enableNativeSwipeToGoBack() -> some View {
        self.background(NativeSwipeToGoBack().frame(width: 0, height: 0))
    }
}
