//
//  PencilIcon.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 01/12/25.
//

import SwiftUI

struct PencilPanel: View {
    var isScrolling: Bool
    var rowHeight: CGFloat = 44
    var verticalAlignment: VerticalAlignment = .center
    
    init(isScrolling: Bool, rowHeight: CGFloat = 44, verticalAlignment: VerticalAlignment = .center) {
        self.isScrolling = isScrolling
        self.rowHeight = rowHeight
        self.verticalAlignment = verticalAlignment
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            VStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(.black)

                Text("Editar")
                    .font(.caption2)
                    .foregroundColor(.black.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 12)
        }
        .frame(height: 100)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.green))
        )
        .opacity(isScrolling ? 0 : 1)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
    }
}

