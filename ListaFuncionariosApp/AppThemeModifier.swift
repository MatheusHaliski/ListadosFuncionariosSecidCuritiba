import SwiftUI

/// A central place to apply app-wide theming and common view modifiers.
/// Extend this as your design system grows.
struct AppThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Example global styling hooks. Adjust as needed.
            .tint(.accentColor)
    }
}

extension View {
    /// Convenience for applying the app's theme modifier.
    func appTheme() -> some View {
        self.modifier(AppThemeModifier())
    }
}
