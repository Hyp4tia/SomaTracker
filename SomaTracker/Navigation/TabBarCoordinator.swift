//
//  TabBarCoordinator.swift
//  SomaTracker
//
//  Smoothly hides and restores the floating tab bar alongside navigation push/pop transitions
//  using UIKit transitionCoordinator, eliminating the native SwiftUI pop-in delay.
//

import SwiftUI
import UIKit

struct TabBarCoordinator: UIViewControllerRepresentable {
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

            // Ultra-fast fade out (0.12s)
            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                tabBar.alpha = 0.0
            }

            if let tc = transitionCoordinator {
                tc.animate(alongsideTransition: nil) { context in
                    if !context.isCancelled {
                        tabBar.isHidden = true
                        tabBar.isUserInteractionEnabled = false
                    } else {
                        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                            tabBar.alpha = 1.0
                        }
                        tabBar.isHidden = false
                        tabBar.isUserInteractionEnabled = true
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    tabBar.isHidden = true
                    tabBar.isUserInteractionEnabled = false
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            guard isEnabled else { return }
            guard let tabBar = resolvedTabBarController?.tabBar else { return }

            // Immediately unhide tab bar and trigger ultra-fast fade in (0.12s)
            tabBar.isHidden = false
            tabBar.isUserInteractionEnabled = true

            UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                tabBar.alpha = 1.0
            }

            if let tc = transitionCoordinator {
                tc.animate(alongsideTransition: nil) { context in
                    if context.isCancelled {
                        // User cancelled the interactive swipe-back gesture
                        UIView.animate(withDuration: 0.12, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                            tabBar.alpha = 0.0
                        }
                        tabBar.isHidden = true
                        tabBar.isUserInteractionEnabled = false
                    } else {
                        tabBar.alpha = 1.0
                        tabBar.isHidden = false
                        tabBar.isUserInteractionEnabled = true
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
