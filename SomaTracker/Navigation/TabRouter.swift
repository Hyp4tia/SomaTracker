//
//  TabRouter.swift
//  SomaTracker
//

import Foundation
import Observation

enum Tab: Hashable {
    case home
    case settings
}

@Observable
final class TabRouter {
    var selectedTab: Tab = .home
}
