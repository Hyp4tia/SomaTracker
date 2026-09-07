//
//  InteractivePopGesture.swift
//  SomaTracker
//
//  Restores native iOS interactive edge swipe-to-go-back when navigationBarBackButtonHidden is true.
//

import UIKit
import SwiftUI


private final class PopGestureCoordinator: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureCoordinator()

    weak var targetNavController: UINavigationController?

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let nav = targetNavController else { return false }
        guard nav.viewControllers.count > 1 else { return false }

        // Must be a rightward horizontal swipe (like standard iOS navigation in Profile)
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: gestureRecognizer.view)
            return velocity.x > 0 && abs(velocity.x) > abs(velocity.y)
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Must return false so inner scroll views do not fight or cancel the navigation pop
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Child scroll views (e.g. ScrollView) must yield to the navigation pop gesture
        return true
    }
}

// 2. Direct Responder Chain view helper to actively hook into the active UINavigationController
private final class PopGestureEnablingView: UIView {
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
        PopGestureCoordinator.shared.targetNavController = nav
        nav.interactivePopGestureRecognizer?.isEnabled = true
        nav.interactivePopGestureRecognizer?.delegate = PopGestureCoordinator.shared
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
