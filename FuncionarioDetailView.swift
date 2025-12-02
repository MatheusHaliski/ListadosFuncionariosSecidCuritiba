
import SwiftUI
internal import CoreData

struct FuncionarioDetailView: View {
    let funcionario: Funcionario
    let onEdit: (() -> Void)?

    @Environment(\.managedObjectContext) private var viewContext

    @State private var mostrandoEdicao = false
    @State private var isFavorite: Bool

    init(funcionario: Funcionario, onEdit: (() -> Void)? = nil) {
        self.funcionario = funcionario
        self.onEdit = onEdit
        _isFavorite = State(initialValue: funcionario.favorito)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // MARK: - PHOTO HEADER
                VStack(spacing: 14) {
                    profileImage
                        .padding(.top, 20)

                    Text(funcionario.nome ?? "Sem nome")
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)

                    if let funcao = funcionario.funcao, !funcao.isEmpty {
                        Text(funcao)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().padding(.horizontal, 32)

                // MARK: - INFO SECTIONS
                VStack(spacing: 18) {
                    infoSection(title: "Regional", value: funcionario.regional)
                    infoSection(title: "Ramal", value: funcionario.ramal)
                    infoSection(title: "Celular", value: funcionario.celular)
                    emailSection
                }
                .padding(.horizontal, 24)

                // MARK: - FAVORITE TOGGLE
                favoriteToggle
                    .padding(.top, 12)

                Spacer().frame(height: 20)
            }
        }

        .navigationTitle("Detalhes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onEdit = onEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        mostrandoEdicao = true
                        onEdit()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $mostrandoEdicao) {
            NavigationStack {
                FuncionarioFormView(
                    regional: funcionario.regional ?? "",
                    funcionario: funcionario,
                    isEditando: true
                )
            }
        }
        .onChange(of: funcionario.favorito) { newValue in
            isFavorite = newValue
        }
    }

    // MARK: - PROFILE IMAGE
    private var profileImage: some View {
        ZStack {
            if let data = funcionario.imagem,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                let name = (funcionario.nome ?? "")
                let initials = name.split(separator: " ").prefix(2)
                    .map { String($0.prefix(1)).uppercased() }.joined()

                Circle().fill(Color(.systemGray5))
                Text(initials.isEmpty ? "?" : initials)
                    .font(.largeTitle.bold())
                    .foregroundColor(.primary)
            }
        }
        .frame(width: 140, height: 140)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(Color.blue.opacity(0.25), lineWidth: 3)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 4)
    }

    // MARK: - FAVORITE
    private var favoriteToggle: some View {
        Toggle(isOn: Binding(
            get: { isFavorite },
            set: toggleFavorite(_:))
        ) {
            Label("Favorito", systemImage: "star.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .gray)
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .toggleStyle(SwitchToggleStyle(tint: .yellow))
        .padding(.horizontal, 32)
    }

    // MARK: - BASIC INFO BOX
    private func infoSection(title: String, value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.body.weight(.medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - EMAIL BOX
    private var emailSection: some View {
        Group {
            if let email = funcionario.email, !email.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Email")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.blue)
                        Text(email)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - FAVORITE TOGGLE LOGIC
    private func toggleFavorite(_ newValue: Bool) {
        isFavorite = newValue
        funcionario.favorito = newValue

        do {
            try viewContext.save()
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)

            FirestoreMigrator.uploadFuncionario(objectID: funcionario.objectID, context: viewContext) { result in
                switch result {
                case .success:
                    print("[FuncionarioDetail] Favorito atualizado no Firestore")
                case .failure(let error):
                    print("[FuncionarioDetail] Erro ao atualizar favorito: \(error.localizedDescription)")
                }
            }

        } catch {
            print("[FuncionarioDetail] Erro ao salvar favorito: \(error.localizedDescription)")
        }
    }
}

