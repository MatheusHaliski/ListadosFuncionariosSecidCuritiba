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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                ZStack {
                    if let data = funcionario.imagem, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                    } else {
                        let name = (funcionario.nome ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        let initials = name.split(separator: " ").prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
                        Circle().fill(Color(.secondarySystemFill))
                        Text(initials.isEmpty ? "?" : initials)
                            .font(.largeTitle.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                Spacer()
            }
            Text(funcionario.nome ?? "Sem nome").font(.title2).fontWeight(.semibold)
            if let funcao = funcionario.funcao { Text(funcao).foregroundColor(.secondary) }
            Divider()
            if let regional = funcionario.regional { Text("Regional: \(regional)") }
            if let ramal = funcionario.ramal, !ramal.isEmpty { Text("Ramal: \(ramal)") }
            if let celular = funcionario.celular, !celular.isEmpty { Text("Celular: \(celular)") }
            if let email = funcionario.email, !email.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                    Text("Email: \(email)")
                        .foregroundColor(.blue)
                        .textSelection(.enabled)
                }
            }
            Toggle(isOn: Binding(get: { isFavorite }, set: toggleFavorite(_:))) {
                Label("Favorito", systemImage: "star.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.yellow, .secondary)
            }
            .toggleStyle(SwitchToggleStyle(tint: .yellow))
            Spacer()
        }
        .padding()
        .navigationTitle("Detalhes")
        .toolbar {
            if let onEdit = onEdit {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar", action: onEdit)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Editar") { mostrandoEdicao = true }
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
