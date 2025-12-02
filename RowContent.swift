//
//  RowContent.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 01/12/25.
//

import SwiftUI


struct RowContent: View {
    let funcionario: Funcionario
    let zoom: CGFloat
    
    var body: some View {
        HStack(alignment: .top, spacing: 12 * zoom) {
            FuncionarioRowViewV2(funcionario: funcionario, showsFavorite: false)
                .foregroundStyle(Color.black)
                .tint(Color.black)
                .fixedSize(horizontal: false, vertical: true)
                .scaleEffect(zoom, anchor: .topLeading)
        }
        .padding(.vertical, 4 * zoom)
    }
}

