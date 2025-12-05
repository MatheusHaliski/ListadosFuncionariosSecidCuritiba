import SwiftUI

public struct ZoomTopControls: View {
    @Binding var zoom: CGFloat
    @Binding var persistedZoom: Double
    
    public init(zoom: Binding<CGFloat>,persistedZoom: Binding<Double>) {
        self._zoom = zoom
        self._persistedZoom = persistedZoom
    }

    public var body: some View {
        HStack(spacing: 10) {
            // 🔹 Ícone de zoom out
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)

            // 🔹 Slider de zoom
            Slider(
                value: Binding(
                    get: { CGFloat(persistedZoom) },
                    set: { persistedZoom = Double($0) }
                ),
                in: 0.8...2.0,
                step: 0.05
            )
            .tint(.black)
            .frame(width: 130)
            .accentColor(.black)

            // 🔹 Ícone de zoom in
            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}
