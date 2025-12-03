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

    var body: some View {
        ScrollView {
            tableView
                .padding()
        }
        .background(Color.white)
        .navigationTitle("Informações Regionais")
    }

    private var tableView: some View {
        VStack(spacing: 0) {
            headerRow
            horizontalSeparator

            ForEach(dadosRegionais.indices, id: \.self) { index in
                rowView(dadosRegionais[index])

                if index < dadosRegionais.count - 1 {
                    horizontalSeparator
                }
            }
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .stroke(Color.black, lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell(title: "Regional", systemImage: "building.2")
                .frame(maxWidth: .infinity, alignment: .leading)

            verticalSeparator

            headerCell(title: "Chefe", systemImage: "person.fill")
                .frame(maxWidth: .infinity, alignment: .leading)

            verticalSeparator

            headerCell(title: "Ramal", systemImage: "phone.fill")
                .frame(width: 120, alignment: .leading)
        }
    }

    private func headerCell(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white)
    }

    private func rowView(_ info: RegionalInfo) -> some View {
        HStack(spacing: 0) {
            tableCell(info.regional, isHeader: false)
                .frame(maxWidth: .infinity, alignment: .leading)

            verticalSeparator

            tableCell(info.chefe, isHeader: false)
                .frame(maxWidth: .infinity, alignment: .leading)

            verticalSeparator

            tableCell(info.ramalRegional, isHeader: false)
                .frame(width: 120, alignment: .leading)
        }
    }

    private func tableCell(_ text: String, isHeader: Bool) -> some View {
        Text(text)
            .font(isHeader ? .subheadline.weight(.semibold) : .body)
            .foregroundStyle(isHeader ? .primary : .secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color.white)
    }

    private var verticalSeparator: some View {
        Rectangle()
            .fill(Color.black)
            .frame(width: 1)
    }

    private var horizontalSeparator: some View {
        Rectangle()
            .fill(Color.black)
            .frame(height: 1)
    }
}

#Preview {
    NavigationStack {
        InfoRegionais()
    }
}
