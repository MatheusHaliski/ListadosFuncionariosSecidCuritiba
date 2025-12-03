import SwiftUI
#if os(iOS)
import UIKit
#endif

/// A reusable scroll container that allows setting an explicit initial content offset.
/// Useful when the important content is positioned away from the natural origin of the
/// scroll view (e.g., centered within a large canvas).
struct ScrollableOffsetView<Content: View>: View {
    var axes: Axis.Set
    var showsIndicators: Bool
    var initialOffset: CGPoint
    @ViewBuilder var content: () -> Content

    init(
        axes: Axis.Set = [.vertical],
        showsIndicators: Bool = true,
        initialOffset: CGPoint = .zero,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.initialOffset = initialOffset
        self.content = content
    }

    var body: some View {
        #if os(iOS)
        ScrollableOffsetRepresentable(
            axes: axes,
            showsIndicators: showsIndicators,
            initialOffset: initialOffset,
            content: content
        )
        #else
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        #endif
    }
}

#if os(iOS)
private struct ScrollableOffsetRepresentable<Content: View>: UIViewRepresentable {
    var axes: Axis.Set
    var showsIndicators: Bool
    var initialOffset: CGPoint
    var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = showsIndicators && axes.contains(.vertical)
        scrollView.showsHorizontalScrollIndicator = showsIndicators && axes.contains(.horizontal)
        scrollView.alwaysBounceVertical = axes.contains(.vertical)
        scrollView.alwaysBounceHorizontal = axes.contains(.horizontal)

        let hostingController = UIHostingController(rootView: content())
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        context.coordinator.hostingController = hostingController
        context.coordinator.initialOffset = initialOffset

        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        if !axes.contains(.horizontal) {
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor).isActive = true
        }
        if !axes.contains(.vertical) {
            hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor).isActive = true
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content()
        scrollView.showsVerticalScrollIndicator = showsIndicators && axes.contains(.vertical)
        scrollView.showsHorizontalScrollIndicator = showsIndicators && axes.contains(.horizontal)
        scrollView.alwaysBounceVertical = axes.contains(.vertical)
        scrollView.alwaysBounceHorizontal = axes.contains(.horizontal)

        if !context.coordinator.didApplyInitialOffset {
            context.coordinator.didApplyInitialOffset = true
            DispatchQueue.main.async {
                scrollView.setContentOffset(initialOffset, animated: false)
            }
        }
    }

    final class Coordinator {
        var hostingController: UIHostingController<Content>?
        var didApplyInitialOffset = false
        var initialOffset: CGPoint = .zero
    }
}
#endif
