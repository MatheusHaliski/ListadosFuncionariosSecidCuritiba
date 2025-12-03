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

    private let columnSpacing: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    headerRow
                    Divider()

                    ForEach(dadosRegionais.indices, id: \.self) { index in
                        rowView(dadosRegionais[index])

                        if index < dadosRegionais.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Informações Regionais")
    }

    private var headerRow: some View {
        HStack(spacing: columnSpacing) {
            headerCell(title: "Regional", systemImage: "building.2")
                .frame(maxWidth: .infinity, alignment: .leading)

            headerCell(title: "Chefe", systemImage: "person.fill")
                .frame(maxWidth: .infinity, alignment: .leading)

            headerCell(title: "Ramal", systemImage: "phone.fill")
                .frame(width: 120, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func headerCell(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func rowView(_ info: RegionalInfo) -> some View {
        HStack(spacing: columnSpacing) {
            Text(info.regional)
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(info.chefe)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.9)

            Text(info.ramalRegional)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        InfoRegionais()
    }
}
