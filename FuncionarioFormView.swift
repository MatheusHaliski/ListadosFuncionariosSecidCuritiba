/// FuncionarioFormView: View for adding or editing a Funcionario (employee) in Core Data. Handles user input, validation, and saving logic.
import SwiftUI
internal import CoreData
#if os(iOS)
import UIKit
import PhotosUI
#endif

/// Displays a form for creating or editing a Funcionario. Used in the Add flow from HomeView.
struct FuncionarioFormView: View {
    @Environment(\.managedObjectContext) private var viewContext {
        didSet {
            viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    @Environment(\.dismiss) private var dismiss

    let isEditando: Bool
    let onSaved: (() -> Void)?

    // MARK: - Form State Properties
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

    // MARK: - Initializer, seeds state for creation or editing context
    init(regional: String, funcionario: Funcionario, isEditando: Bool, onSaved: (() -> Void)? = nil) {
        self._funcionario = ObservedObject(initialValue: funcionario)
        self.isEditando = isEditando
        self.onSaved = onSaved
        // Seed state from the provided object, falling back to the provided regional
        _regionalText = State(initialValue: (funcionario.regional?.isEmpty == false ? funcionario.regional! : regional))
        _nomeText = State(initialValue: funcionario.nome ?? "")
        _cargoText = State(initialValue: funcionario.funcao ?? "")
        _telefoneText = State(initialValue: funcionario.celular ?? "")
        _emailText = State(initialValue: funcionario.email ?? "")
        _favorito = State(initialValue: funcionario.favorito)
        _fotoData = State(initialValue: funcionario.imagem)
    }

    // MARK: - View Body
    var body: some View {
        Form {
#if os(iOS)
            // Photo selection and preview (iOS only)
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

            // Main Info Section
            Section(header: Text("Informações")) {
                TextField("Nome", text: $nomeText)
                    .textInputAutocapitalization(.words)
                TextField("Cargo", text: $cargoText)
                    .textInputAutocapitalization(.words)
                TextField("Regional", text: $regionalText)
                    .textInputAutocapitalization(.words)
            }

            // Contact Info Section
            Section(header: Text("Contato")) {
                TextField("Telefone", text: $telefoneText)
                    .keyboardType(.phonePad)
                TextField("E-mail", text: $emailText)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section {
                Toggle(isOn: $favorito) {
                    Text("Favorito")
                        .foregroundStyle(.blue)
                }
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
        // Ensure Core Data mutations and save happen on the context's queue
        viewContext.perform {
            viewContext.refresh(funcionario, mergeChanges: true)
            // Apply edited fields back to the Core Data object
            if self.funcionario.id == nil {
                self.funcionario.id = UUID()
            }
            self.funcionario.nome = self.nomeText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.funcionario.funcao = self.cargoText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.funcionario.regional = self.regionalText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.funcionario.celular = self.telefoneText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.funcionario.email = self.emailText.trimmingCharacters(in: .whitespacesAndNewlines)
            self.funcionario.favorito = self.favorito
            self.funcionario.imagem = self.fotoData

            do {
                try self.viewContext.save()

                // Notify and upload on the main actor after a successful save
                Task { @MainActor in
                    NotificationCenter.default.post(name: .funcionarioAtualizado, object: nil)
                    FirestoreMigrator.uploadFuncionario(objectID: self.funcionario.objectID, context: self.viewContext) { result in
                        switch result {
                        case .success:
                            print("[FuncionarioForm] Upload OK: \(self.funcionario.objectID)")
                        case .failure(let error):
                            print("[FuncionarioForm] Upload ERRO: \(error.localizedDescription)")
                        }
                    }
                    self.onSaved?()
                    self.dismiss()
                }
            } catch {
                viewContext.rollback()
                let nsError = error as NSError
                print("Erro ao salvar funcionario: \(nsError.localizedDescription)\nDomain: \(nsError.domain) Code: \(nsError.code)\nUserInfo: \(nsError.userInfo)")
            }
        }
    }
}

