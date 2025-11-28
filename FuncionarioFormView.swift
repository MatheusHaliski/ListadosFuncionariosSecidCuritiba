import SwiftUI
import CoreData
#if os(iOS)
import UIKit
import PhotosUI
#endif

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
    @State private var fotoData: Data?
#if os(iOS)
    @State private var fotoItem: PhotosPickerItem?
#endif

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
        _fotoData = State(initialValue: funcionario.imagem)
    }

    var body: some View {
        Form {
#if os(iOS)
            Section {
                VStack(spacing: 12) {
                    if let fotoData, let uiImage = UIImage(data: fotoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.secondary)
                    }

#if canImport(PhotosUI)
                    PhotosPicker(selection: $fotoItem, matching: .images) {
                        Label("Selecionar foto", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: fotoItem) { newItem in
                        guard let newItem else { return }
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    fotoData = data
                                }
                            }
                        }
                    }
#endif
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
#endif

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
        funcionario.imagem = fotoData

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

