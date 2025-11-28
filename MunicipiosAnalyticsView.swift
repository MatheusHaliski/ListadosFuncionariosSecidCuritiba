//
//  BarChartView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 26/11/25.
//


import SwiftUI
import Charts
struct MunicipiosAnalyticsView<DataItem: Identifiable>: View {
    let data: [DataItem]
    let title: String
    let xValue: KeyPath<DataItem, String>
    let yValue: KeyPath<DataItem, Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            if data.isEmpty {
                ContentUnavailableView("Sem dados para exibir",
                                       systemImage: "chart.bar",
                                       description: Text("Ajuste seus filtros e tente novamente."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(data, id: \.id) { item in
                    BarMark(
                        x: .value("Regional", item[keyPath: xValue]),
                        y: .value("Quantidade", item[keyPath: yValue])
                    )
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .top) {
                        let value = item[keyPath: yValue]
                        Text(String(value))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 360)
                .padding(.horizontal)
            }

            Spacer(minLength: 0)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
