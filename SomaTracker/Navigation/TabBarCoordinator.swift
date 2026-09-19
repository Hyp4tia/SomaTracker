//
//  TabBarCoordinator.swift
//  SomaTracker
//
//  Smoothly hides and restores the floating tab bar alongside navigation push/pop transitions
//  using UIKit transitionCoordinator, eliminating the native SwiftUI pop-in delay.
//

import SwiftUI
import UIKit

/// The one definition of how the floating tab bar hides and returns. Both the navigation path and
/// surfaces that are not a push use these, so their timings cannot drift apart.
enum TabBarAnimation {
    static let duration: TimeInterval = 0.12

    static func hide(_ tabBar: UITabBar) {
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            tabBar.alpha = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            tabBar.isHidden = true
            tabBar.isUserInteractionEnabled = false
        }
    }

    static func show(_ tabBar: UITabBar) {
        tabBar.isHidden = false
        tabBar.isUserInteractionEnabled = true
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            tabBar.alpha = 1.0
        }
    }
}

struct TabBarCoordinator: UIViewControllerRepresentable {
    /// For a surface that is not a navigation push. Its appearance callbacks only arrive once its
    /// removal transition has finished, which leaves the bar missing for the whole animation, so the
    /// chat asks for the change at the moment the transition starts instead.
    static func setTabBarVisible(_ visible: Bool) {
        DispatchQueue.main.async {
            guard let tabBar = resolvedTabBar() else { return }
            visible ? TabBarAnimation.show(tabBar) : TabBarAnimation.hide(tabBar)
        }
    }

    private static func resolvedTabBar() -> UITabBar? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow } ?? scenes.first?.windows.first
        guard let root = window?.rootViewController else { return nil }
        return tabBarController(in: root)?.tabBar
    }

    private static func tabBarController(in controller: UIViewController) -> UITabBarController? {
        if let found = controller as? UITabBarController { return found }
        for child in controller.children {
            if let found = tabBarController(in: child) { return found }
        }
        if let presented = controller.presentedViewController {
            return tabBarController(in: presented)
        }
        return nil
    }

    var isEnabled: Bool = true

    func makeUIViewController(context: Context) -> CoordinatorViewController {
        CoordinatorViewController(isEnabled: isEnabled)
    }

    func updateUIViewController(_ uiViewController: CoordinatorViewController, context: Context) {
        uiViewController.isEnabled = isEnabled
    }

    final class CoordinatorViewController: UIViewController {
        var isEnabled: Bool

        init(isEnabled: Bool) {
            self.isEnabled = isEnabled
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private var resolvedTabBarController: UITabBarController? {
            if let tbc = tabBarController { return tbc }
            if let tbc = navigationController?.tabBarController { return tbc }
            var responder: UIResponder? = self
            while let current = responder {
                if let vc = current as? UITabBarController {
                    return vc
                }
                responder = current.next
            }
            return nil
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard isEnabled else { return }
            guard let tabBar = resolvedTabBarController?.tabBar else { return }

            // Ultra-fast fade out, shared with every other caller.
            TabBarAnimation.hide(tabBar)

            if let tc = transitionCoordinator {
                tc.animate(alongsideTransition: nil) { context in
                    if context.isCancelled {
                        TabBarAnimation.show(tabBar)
                    } else {
                        tabBar.isHidden = true
                        tabBar.isUserInteractionEnabled = false
                    }
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard isEnabled else { return }
            guard let tabBar = resolvedTabBarController?.tabBar else { return }

            // Immediately unhide and fade in, same timings as everywhere else.
            TabBarAnimation.show(tabBar)

            if let tc = transitionCoordinator {
                tc.animate(alongsideTransition: nil) { context in
                    if context.isCancelled {
                        // User cancelled the interactive swipe-back gesture
                        TabBarAnimation.hide(tabBar)
                    } else {
                        TabBarAnimation.show(tabBar)
                    }
                }
            }
        }
    }
}

extension View {
    /// Smoothly hides the floating tab bar on push and restores it interactively on pop with 0ms lag.
    func hideTabBarWithCoordinator(_ isEnabled: Bool = true) -> some View {
        self.background(
            TabBarCoordinator(isEnabled: isEnabled)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        )
    }
}
