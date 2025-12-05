//
//  DetalhesFuncionarioView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 28/10/25.
//

import SwiftUI

struct DetalhesFuncionarioView: View {
    // Placeholder properties for demonstration. Replace with real model as needed.
    var nome: String = "Maria Silva"
    var cargo: String = "Desenvolvedora iOS"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(nome)
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(cargo)
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()

            Text("Detalhes do funcionário virão aqui.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Detalhes")
    }
}

#Preview("Detalhes Funcionário") {
    NavigationStack {
        DetalhesFuncionarioView()
    }
}
