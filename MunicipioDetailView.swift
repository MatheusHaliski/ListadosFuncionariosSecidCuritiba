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
        ScrollView {
            VStack(spacing: 16) {
                // Header card matching RegionalInfoDetailView style
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.tint)
                        Text(municipio.nome ?? "—")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Button(action: toggleFavorite) {
                            Image(systemName: municipio.favorito ? "star.fill" : "star")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(municipio.favorito ? .yellow : .secondary)
                                .contentTransition(.symbolEffect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(municipio.favorito ? "Remover dos favoritos" : "Adicionar aos favoritos")
                    }

                    // Subtitle / secondary line if needed
                    Text("Município")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)

                // Info table-style card matching RegionalInfoDetailView rows/dividers
                VStack(spacing: 0) {
                    // Row: Município
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "building.2")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Município")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(municipio.nome ?? "—")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(16)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    // Row: Regional
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Regional")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(municipio.regional ?? "—")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                    }
                    .padding(16)

                    Divider()
                        .overlay(Color.black.opacity(0.08))

                    // Row: UUID
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "number")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UUID")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text((municipio.id as? UUID)?.uuidString ?? ((municipio.id as? NSUUID).map { ($0 as UUID).uuidString } ?? "—"))
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)

                // Full-width favorite action matching pattern
                Button(action: toggleFavorite) {
                    HStack(spacing: 12) {
                        Image(systemName: municipio.favorito ? "star.fill" : "star")
                            .font(.system(size: 20, weight: .semibold))
                        Text(municipio.favorito ? "Remover dos favoritos" : "Adicionar aos favoritos")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(municipio.favorito ? .yellow : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .navigationTitle("Município")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
    }

    private func toggleFavorite() {
        let newValue = !municipio.favorito
        withAnimation {
            // Optimistic UI update
            municipio.favorito = newValue
            do { try viewContext.save() } catch { print("Erro ao salvar favorito: \(error)") }
        }
        // Push to Firestore and log on success
        FirestoreMigrator.updateMunicipioFavorito(
            objectID: municipio.objectID,
            favorito: newValue,
            context: viewContext
        ) { result in
            switch result {
            case .success:
                NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
            case .failure(let err):
                print("[Detail] Falha ao atualizar favorito no Firestore: \(err)")
            }
        }
    }
}
