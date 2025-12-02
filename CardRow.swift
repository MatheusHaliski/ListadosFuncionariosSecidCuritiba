import SwiftUI
struct CardRow: View {
    let funcionario: Funcionario
    let zoom: CGFloat
    let isScrolling: Bool
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            
            // CARD CONTENT
            NavigationLink(destination: FuncionarioDetailView(funcionario: funcionario)) {
                RowContent(funcionario: funcionario, zoom: zoom)
                    .padding(.vertical, 18 * zoom)
                    .padding(.horizontal, 22 * zoom)
                    .frame(minWidth: 320 * zoom, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.15),
                                    radius: 5 * zoom,
                                    x: 0,
                                    y: 3 * zoom)
                    )
            }
            .buttonStyle(.plain)
            .foregroundColor(.black)

            // PENCIL PANEL
            Button(action: onEdit) {
                PencilPanel(isScrolling: isScrolling)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10 * zoom)
        .padding(.horizontal, 12)
    }
}

