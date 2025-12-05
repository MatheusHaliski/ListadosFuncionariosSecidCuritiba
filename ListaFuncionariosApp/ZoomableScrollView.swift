import SwiftUI
import UIKit

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    var minZoomScale: CGFloat = 1.0
    var maxZoomScale: CGFloat = 3.0
    var onZoom: ((CGFloat) -> Void)?
    @ViewBuilder var content: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoomScale
        scrollView.maximumZoomScale = maxZoomScale
        scrollView.zoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear

        // Host SwiftUI content
        let hosting = UIHostingController(rootView: content())
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        context.coordinator.hostingController = hosting

        scrollView.addSubview(hosting.view)

        // Pin hosted view to scroll view's content layout
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // Store width constraint for updates
        context.coordinator.widthConstraint = hosting.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        context.coordinator.widthConstraint?.isActive = true

        // Double tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the hosted SwiftUI content
        if let hosting = context.coordinator.hostingController {
            hosting.rootView = content()
        }
        // Keep constraints for width pinning in sync when size class changes
        if let widthConstraint = context.coordinator.widthConstraint {
            widthConstraint.isActive = false
            if let hostingView = uiView.subviews.first {
                context.coordinator.widthConstraint = hostingView.widthAnchor.constraint(equalTo: uiView.frameLayoutGuide.widthAnchor)
                context.coordinator.widthConstraint?.isActive = true
            }
        }
        centerContent(in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    // Center content when it's smaller than the scroll view
    private func centerContent(in scrollView: UIScrollView) {
        guard let contentView = scrollView.subviews.first else { return }
        let offsetX = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0)
        contentView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                     y: scrollView.contentSize.height * 0.5 + offsetY)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        weak var hostingController: UIHostingController<Content>?
        var widthConstraint: NSLayoutConstraint?

        init(parent: ZoomableScrollView) {
            self.parent = parent
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            parent.onZoom?(scrollView.zoomScale)
            // Recenter content after zooming
            let offsetX = max((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5, 0)
            hostingController?.view.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                                     y: scrollView.contentSize.height * 0.5 + offsetY)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            let newScale: CGFloat
            if scrollView.zoomScale < (parent.maxZoomScale + parent.minZoomScale) / 2 {
                newScale = min(scrollView.zoomScale * 2, parent.maxZoomScale)
            } else {
                newScale = parent.minZoomScale
            }

            let pointInView = gesture.location(in: hostingController?.view)
            let scrollViewSize = scrollView.bounds.size

            let w = scrollViewSize.width / newScale
            let h = scrollViewSize.height / newScale
            let x = pointInView.x - (w / 2.0)
            let y = pointInView.y - (h / 2.0)
            let rectToZoom = CGRect(x: x, y: y, width: w, height: h)

            scrollView.zoom(to: rectToZoom, animated: true)
        }
    }
}
