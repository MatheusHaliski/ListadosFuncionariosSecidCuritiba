import SwiftUI
import CoreData

struct FuncionarioFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let isEditando: Bool

    // The Core Data object being edited
    @ObservedObject var funcionario: Funcionario

    // A convenience for initial regional passed in (used when creating or as default)
    @State private var regionalText: String
    @State private var nomeText: String
    @State private var cargoText: String
    @State private var telefoneText: String
    @State private var emailText: String
    @State private var favorito: Bool

    init(regional: String, funcionario: Funcionario, isEditando: Bool) {
        self._funcionario = ObservedObject(initialValue: funcionario)
        self.isEditando = isEditando
        // Seed state from the provided object, falling back to the provided regional
        _regionalText = State(initialValue: funcionario.regional ?? regional)
        _nomeText = State(initialValue: funcionario.nome ?? "")
        _cargoText = State(initialValue: funcionario.funcao ?? "")
        _telefoneText = State(initialValue: funcionario.celular ?? "")
        _emailText = State(initialValue: funcionario.email ?? "")
        _favorito = State(initialValue: funcionario.favorito)
    }

    var body: some View {
        Form {
            Section(header: Text("Informações")) {
                TextField("Nome", text: $nomeText)
                    .textInputAutocapitalization(.words)
                TextField("Cargo", text: $cargoText)
                    .textInputAutocapitalization(.words)
                TextField("Regional", text: $regionalText)
                    .textInputAutocapitalization(.words)
            }

            Section(header: Text("Contato")) {
                TextField("Telefone", text: $telefoneText)
                    .keyboardType(.phonePad)
                TextField("E-mail", text: $emailText)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section {
                Toggle("Favorito", isOn: $favorito)
            }
        }
        .navigationTitle(isEditando ? "Editar Servidor" : "Novo Servidor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { saveAndDismiss() }
                    .disabled(nomeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func saveAndDismiss() {
        // Apply edited fields back to the Core Data object
        funcionario.nome = nomeText.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.funcao = cargoText.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.regional = regionalText.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.celular = telefoneText.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.email = emailText.trimmingCharacters(in: .whitespacesAndNewlines)
        funcionario.favorito = favorito

        do {
            try viewContext.save()
            // Notify listeners similarly to FavoritesView usage
            NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
            dismiss()
        } catch {
            // In a real app, present an alert; for now we log
            print("Erro ao salvar funcionario: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview (requires mock managed object context and entity)
#if DEBUG
struct FuncionarioFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        // Create or fetch a sample Funcionario for preview
        let f = Funcionario(context: context)
        f.nome = "Fulano de Tal"
        f.funcao = "Analista"
        f.regional = "Regional X"
        f.celular = "(11) 99999-9999"
        f.email = "fulano@example.com"
        f.favorito = true

        return NavigationView {
            FuncionarioFormView(
                regional: f.regional ?? "",
                funcionario: f,
                isEditando: true
            )
            .environment(\.managedObjectContext, context)
        }
    }
}
#endif
