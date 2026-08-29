//
//  TabRouter.swift
//  SomaTracker
//

import Foundation
import Observation

enum Tab: Hashable {
    case home
    case ai
    case settings
}

@Observable
final class TabRouter {
    var selectedTab: Tab = .home
}
