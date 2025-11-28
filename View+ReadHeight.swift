import SwiftUI

private struct ViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ReadHeightModifier: ViewModifier {
    @Binding var height: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: ViewHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ViewHeightPreferenceKey.self) { newHeight in
                height = newHeight
            }
    }
}

extension View {
    func readHeight(_ height: Binding<CGFloat>) -> some View {
        self.modifier(ReadHeightModifier(height: height))
    }
}
