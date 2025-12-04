//
//  ZoomLayoutModifier.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 03/12/25.
//

import SwiftUI


struct ZoomLayoutModifier: ViewModifier {
    @AppStorage("app_zoom_scale") private var zoom: Double = 1.35

    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .frame(
                    width: geo.size.width * zoom,
                    height: geo.size.height * zoom,
                    alignment: .topLeading
                )
                .animation(.easeInOut, value: zoom)
        }
    }
}

extension View {
    func zoomLayout() -> some View {
        self.modifier(ZoomLayoutModifier())
    }
}
