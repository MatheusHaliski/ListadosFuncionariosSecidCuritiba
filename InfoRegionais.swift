import SwiftUI

struct RegionalInfo: Identifiable {
    let id = UUID()
    let regional: String
    let chefe: String
    let ramalRegional: String
}

struct InfoRegionais: View {
    private let dadosRegionais: [RegionalInfo] = [
        RegionalInfo(regional: "Regional 1", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 2", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 3", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 4", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 5", chefe: "Nome do Chefe", ramalRegional: "0000")
    ]

    private var colunasFlex: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), alignment: .leading),
            GridItem(.flexible(minimum: 140), alignment: .leading),
            GridItem(.flexible(minimum: 100), alignment: .leading)
        ]
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVGrid(columns: colunasFlex, alignment: .leading, spacing: 12, pinnedViews: [.sectionHeaders]) {
                Section(header: headerView) {
                    ForEach(dadosRegionais) { regional in
                        HStack(spacing: 12) {
                            Text(regional.regional)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(regional.chefe)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(regional.ramalRegional)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Informações Regionais")
        .background(Color(.systemGroupedBackground))
    }

    private var headerView: some View {
        HStack(spacing: 12) {
            Label("Regional", systemImage: "building.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Label("Chefe", systemImage: "person.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Label("Ramal", systemImage: "phone.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color.blue.opacity(0.15), Color.indigo.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .padding(.bottom, 4)
    }
}

#Preview {
    NavigationStack {
        InfoRegionais()
    }
}
