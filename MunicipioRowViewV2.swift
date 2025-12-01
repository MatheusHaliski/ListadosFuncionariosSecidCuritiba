import SwiftUI
internal import CoreData

public struct MunicipioRowViewV2: View {
    let municipio: Municipio
    let onToggleFavorite: () -> Void
    @State private var isAnimatingFavorite: Bool = false
    @Environment(\.managedObjectContext) private var context

    public init(municipio: Municipio, onToggleFavorite: @escaping () -> Void) {
        self.municipio = municipio
        self.onToggleFavorite = onToggleFavorite
    }

    public var body: some View {
        VStack(spacing: 8) {

            Text(municipio.nome ?? "—")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.08))
                )

            VStack(alignment: .center, spacing: 6) {
                if let regional = municipio.regional, !regional.isEmpty {
                    Text("Regional: \(regional)")
                        .font(.system(size: 26, weight: .semibold))
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)

            Divider()

            // ⭐ BOTÃO FAVORITO
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                Button(action: {
                    animateFavorite()
                    toggleFavoriteAndSync()
                }) {
                    Image(systemName: (municipio.favorito == true) ? "star.fill" : "star")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle((municipio.favorito == true) ? Color.yellow : Color.gray)
                        .frame(width: 26, height: 56)
                        .background(Circle().fill(Color(.systemBackground)))
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                        .shadow(radius: 2)
                        .scaleEffect(isAnimatingFavorite ? 1.12 : 1.0)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 28)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black.opacity(0.1), lineWidth: 1))
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 1))
        }
        .padding(.vertical, 28)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.black, lineWidth: 1.4))
        .shadow(color: .gray.opacity(0.2), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 6)
        .frame(maxWidth: 528, alignment: .center)
        .animation(.default, value: municipio.favorito)
    }

    // MARK: - Animations
    private func animateFavorite() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isAnimatingFavorite = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isAnimatingFavorite = false
            }
        }
    }

    // MARK: - Logic + Firestore Upload
    private func toggleFavoriteAndSync() {
        // 1) Toggle locally
        onToggleFavorite()

        // 2) Save Core Data immediately so we send the latest value
        do {
            try context.save()
        } catch {
            print("❌ Erro ao salvar Core Data: \(error.localizedDescription)")
            return
        }

        // 3) Reload the updated object from Core Data to avoid stale values
        let updatedMunicipio: Municipio
        do {
            updatedMunicipio = try context.existingObject(with: municipio.objectID) as! Municipio
        } catch {
            print("❌ Erro ao recarregar objeto atualizado:", error.localizedDescription)
            return
        }

        FirestoreMigrator.uploadMunicipio(
            objectID: municipio.objectID,
            context: context
        ) { result in
            switch result {
            case .success:
                print("✓ Município atualizado no Firebase")
            case .failure(let error):
                print("❌ Erro ao atualizar município:", error.localizedDescription)
            }
        }

    }

}
