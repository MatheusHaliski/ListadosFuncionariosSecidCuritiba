import SwiftUI
import Combine

final class ZoomManager: ObservableObject {
    @Published var scale: CGFloat

    private let minScale: CGFloat
    private let maxScale: CGFloat
    private let step: CGFloat

    init(scale: CGFloat = 1.0, minScale: CGFloat = 0.8, maxScale: CGFloat = 1.6, step: CGFloat = 0.1) {
        self.scale = scale
        self.minScale = minScale
        self.maxScale = maxScale
        self.step = step
    }

    func increase() {
        withAnimation(.easeInOut) {
            scale = min(scale + step, maxScale)
        }
    }

    func decrease() {
        withAnimation(.easeInOut) {
            scale = max(scale - step, minScale)
        }
    }

    func reset() {
        withAnimation(.easeInOut) {
            scale = 1.0
        }
    }
}
