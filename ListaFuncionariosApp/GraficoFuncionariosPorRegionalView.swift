import SwiftUI
import Charts
import Playgrounds

struct GraficoFuncionariosPorRegionalView: View {
    let data: [MunicipiosPorRegional]
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Funcionários por Regional")
                    .font(.title2.bold())
                    .padding(.top)
                    .padding(.horizontal)
                
                Chart(data) { item in
                    BarMark(
                        x: .value("Quantidade", item.count),
                        y: .value("Regional", item.regional)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .trailing, alignment: .center) {
                        Text("\(item.count)")
                            .font(.callout.weight(.semibold))
                            .foregroundColor(.blue)
                            .padding(.leading, 4)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#Preview {
    GraficoFuncionariosPorRegionalView(data: [])
}


#Preview {
    NavigationStack {
        GraficoFuncionariosPorRegionalView(data: [
            MunicipiosPorRegional(regional: "Norte", count: 12),
            MunicipiosPorRegional(regional: "Sul", count: 8),
            MunicipiosPorRegional(regional: "Leste", count: 15),
            MunicipiosPorRegional(regional: "Oeste", count: 6),
            MunicipiosPorRegional(regional: "Centro", count: 20)
        ])
    }
}

