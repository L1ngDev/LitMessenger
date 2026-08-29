import SwiftUI

extension View {
    @ViewBuilder
    func liquidGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    func glassToolbar() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackground(.glassEffect(), for: .navigationBar)
        } else {
            self.toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }

    @ViewBuilder
    func glassTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.toolbarBackground(.glassEffect(), for: .tabBar)
        } else {
            self
        }
    }
}
