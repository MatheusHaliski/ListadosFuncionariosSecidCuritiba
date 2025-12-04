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
        RegionalInfo(regional: "Regional 5", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 1", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 2", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 3", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 4", chefe: "Nome do Chefe", ramalRegional: "0000"),
        RegionalInfo(regional: "Regional 5", chefe: "Nome do Chefe", ramalRegional: "0000")
    ]

    private let columnSpacing: CGFloat = 32

    var body: some View {

        ScrollView(.vertical, showsIndicators: true) {   // <-- SCROLL RESTAURADO
            VStack(spacing: 40) {

                VStack(spacing: 0) {

                    // MARK: - HEADER
                    headerRow
                        .frame(height: 100)
                        .frame(width:.infinity)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.18))
                        .overlay(
                            Rectangle()
                                .fill(Color.blue.opacity(0.35))
                                .frame(height: 2),
                            alignment: .bottom
                        )

                    Divider()

                    // MARK: - LINHAS
                    ForEach(dadosRegionais.indices, id: \.self) { index in
                        rowView(dadosRegionais[index])
                            .frame(height: 95)  // Altura grande das linhas

                        if index < dadosRegionais.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 35)
                .padding(.horizontal, 30)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                .shadow(color: Color.black.opacity(0.10), radius: 12, x: 0, y: 4)
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Informações Regionais")
    }

    // MARK: HEADER
    private var headerRow: some View {
        HStack(spacing: columnSpacing) {

            headerCell(title: "Regional", systemImage: "building.2")
                .frame(maxWidth: 180, alignment: .center)

            headerCell(title: "Chefe", systemImage: "person.fill")
                .frame(maxWidth: .infinity, alignment: .center)

            headerCell(title: "Ramal", systemImage: "phone.fill")
                .frame(width: 180, alignment: .center)
        }
    }

    private func headerCell(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(.blue)
    }

    // MARK: ROWS
    private func rowView(_ info: RegionalInfo) -> some View {
        HStack(spacing: columnSpacing) {

            Text(info.regional)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(info.chefe)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(info.ramalRegional)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
    }
}

#Preview {
    NavigationStack {
        InfoRegionais()
            .preferredColorScheme(.light)
    }
}

