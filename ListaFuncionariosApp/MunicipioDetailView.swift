import SwiftUI
internal import CoreData

extension Notification.Name {
    static let funcionarioAtualizado = Notification.Name("funcionarioAtualizado")
}

struct MunicipioDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var municipio: Municipio

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                
                // ⭐ Updated: Add prefix "Regional:"
                Text("Município: \(municipio.nome ?? "—")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                // ⭐ Updated: Add prefix "Regional:"
                Text("Regional: \(municipio.regional ?? "—")")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)

            Button(action: toggleFavorite) {
                HStack(spacing: 12) {
                    Image(systemName: municipio.favorito ? "star.fill" : "star")
                        .font(.system(size: 22, weight: .semibold))
                    Text(municipio.favorito ? "Remover dos favoritos" : "Adicionar aos favoritos")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(municipio.favorito ? .yellow : .blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Município")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggleFavorite() {
        withAnimation {
            municipio.favorito.toggle()
            do { try viewContext.save() } catch { print("Erro ao salvar favorito: \(error)") }
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
        }
    }
}

