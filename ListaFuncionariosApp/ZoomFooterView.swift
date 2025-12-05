//
//  ZoomFooterView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 27/10/25.
//


import SwiftUI

struct ZoomFooterView: View {
    @Binding var zoomScale: CGFloat
    var color: Color = .blue // permite customização de cor

    var body: some View {
        VStack {
            Text(String(format: "Zoom: %.0f%%", zoomScale * 100))
                .font(.caption)
                .foregroundColor(.secondary)

            Slider(value: $zoomScale, in: 0.8...2.0, step: 0.05)
                .tint(color)
                .padding(.horizontal, 60)
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(radius: 3)
        .padding(.bottom, 8)
    }
}
