//
//  BarChartView.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 26/11/25.
//

import Foundation
import SwiftUI
import Charts

protocol RegionalCountable {
    var regional: String { get }
    var count: Int { get }
}

private struct ChartHeader: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.primary)

            Text("Distribuição por Regional")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal)
    }
}

struct MunicipiosAnalyticsView<DataItem: RegionalCountable>: View {
    let data: [DataItem]
    let title: String
    
    @ViewBuilder
    private var chartContent: some View {
        if data.isEmpty {
            ContentUnavailableView(
                "Sem dados para exibir",
                systemImage: "chart.bar",
                description: Text("Ajuste seus filtros e tente novamente.")
            )
        } else {
            ZoomableScrollView3(minZoomScale: 0.8, maxZoomScale: 3.0) {
                ChartContainerView(data: data)
            }
        }
    }
    
    private struct ChartContainerView: View {
        let data: [DataItem]
    
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                RegionalBarChart(data: data)
                    .frame(minWidth: 1000, minHeight: 500)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.8), lineWidth: 6)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
            .padding(.horizontal)
        }
    }
    
    private struct RegionalBarChart: View {
        let data: [DataItem]
    
        var body: some View {
            Chart {
                // Use regional como ID (sempre único após agregação)
                ForEach(data, id: \.regional) { item in
                    BarMark(
                        x: .value("Regional", item.regional),
                        y: .value("Quantidade", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .annotation(position: .top) {
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            .chartXAxisLabel(position: .bottom, alignment: .center) {
                Text("Regionais")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.blue)
            }

            .chartYAxisLabel(position: .leading, alignment: .center) {
                Text("Quantidade")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.blue)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ChartHeader(title: title)
            chartContent
            Spacer(minLength: 0)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - CONFORMIDADE
extension MunicipiosAnalyticsView where DataItem == MunicipiosPorRegional {
    init(title: String, data: [MunicipiosPorRegional]) {
        self.data = data
        self.title = title
    }
}

extension MunicipiosPorRegional: RegionalCountable {}

struct FuncionariosPorRegionalChartView: View {
    let funcionarios: [Funcionario]

    var body: some View {
        let aggregated = AnalyticsAggregator.aggregateFuncionariosByRegional(funcionarios)
        MunicipiosAnalyticsView(
            title: "Funcionários x Regionais",
            data: aggregated
        )
    }
}

struct MunicipiosPorRegionalChartView: View {
    let municipios: [Municipio]

    var body: some View {
        let aggregated = AnalyticsAggregator.aggregateMunicipiosByRegional(municipios)
        MunicipiosAnalyticsView(
            title: "Municípios x Regionais",
            data: aggregated
        )
    }
}

