//
//  ZoomBarTopView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 28/10/25.
//


import SwiftUI

struct ZoomBarTopView: View {
    @Binding var zoom: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "minus.magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Slider(value: $zoom, in: 0.8...2.0, step: 0.05)
                .tint(.blue)
                .frame(width: 120)

            Image(systemName: "plus.magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 1)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 6)
    }
}
