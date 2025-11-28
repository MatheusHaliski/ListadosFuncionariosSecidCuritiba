import SwiftUI

struct FuncionarioRowViewV2: View {
    let funcionario: Funcionario
    @State private var image: UIImage? = nil
    @State private var isLoadingImage = false

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
            if funcionario.favorito {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .accessibilityLabel("Favorito")
            }
        }
        .padding(.vertical, 8)
        .onAppear(perform: loadImage)
    }

    private func loadImage() {
        // Try Core Data binary image first (Data)
        if let imageData = funcionario.imagem as? Data, let uiImage = UIImage(data: imageData) {
            self.image = uiImage
            return
        }

        // Try URL string next (if the model stores a URL string)
        if let urlString = funcionario.imagem as? String, let url = URL(string: urlString) {
            isLoadingImage = true
            ImageStorage.downloadImage(from: url) { result in
                DispatchQueue.main.async {
                    isLoadingImage = false
                    switch result {
                    case .success(let data):
                        if let uiImage = UIImage(data: data) {
                            self.image = uiImage
                        }
                    case .failure:
                        // Fallback image already handled by default state
                        break
                    }
                }
            }
            return
        }

        // If neither Data nor a valid URL string is available, keep showing the placeholder
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
