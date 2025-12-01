import SwiftUI
internal import CoreData

struct FuncionarioRowViewV2: View {
    let funcionario: Funcionario
    let showsFavorite: Bool
    @State private var image: UIImage? = nil
    @State private var isLoadingImage = false

    init(funcionario: Funcionario, showsFavorite: Bool = true) {
        self.funcionario = funcionario
        self.showsFavorite = showsFavorite
    }

    var body: some View {
        HStack(spacing: 16) {
            Group {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                } else if isLoadingImage {
                    ProgressView()
                        .frame(width: 56, height: 56)
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .foregroundStyle(.secondary)
                }
            }
            .animation(.easeInOut, value: image)

            VStack(alignment: .leading, spacing: 4) {
                Text(funcionario.nome ?? "(Sem nome)")
                    .font(.headline)
                Text(funcionario.funcao ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let regional = funcionario.regional {
                    Text(regional)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            if showsFavorite, funcionario.favorito {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .accessibilityLabel("Favorito")
            }
        }
        .padding(.vertical, 8)
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        // Images must come from Core Data only. If the record doesn't have binary data yet,
        // we intentionally keep showing the placeholder instead of re-downloading from Firebase.
        if let imageData = funcionario.imagem as? Data, let uiImage = UIImage(data: imageData) {
            self.image = uiImage
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let funcionario = Funcionario(context: context)
    funcionario.nome = "Maria Silva"
    funcionario.funcao = "Analista"
    funcionario.regional = "São Paulo"
    funcionario.favorito = true
    return FuncionarioRowViewV2(funcionario: funcionario)
}

