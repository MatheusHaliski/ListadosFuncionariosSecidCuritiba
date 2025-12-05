import SwiftUI
internal import CoreData

struct RegionalFormView: View {
    // Optional existing regional to edit. If nil, we create a new one on save.
    var regional: RegionalInfo5?
    var onSaved: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var nome: String = ""
    @State private var endereco: String = ""
    @State private var chefe: String = ""
    @State private var ramal: String = ""

    // Local state to detect if we have prefilled values
    @State private var hasPrefilled = false

    #if DEBUG
    @State private var showPurgeConfirmation = false
    #endif

    var body: some View {
        Form {
            Section(header: Text("Identificação")) {
                TextField("Nome da Regional", text: $nome)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
            }

            Section(header: Text("Endereço")) {
                TextField("Endereço", text: $endereco)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
            }

            Section(header: Text("Chefia")) {
                TextField("Chefe", text: $chefe)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
            }

            Section(header: Text("Contato")) {
                TextField("Telefone / Ramal", text: $ramal)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
        .onAppear { prefillFromExistingIfNeeded() }
        .navigationTitle(regional == nil ? "Nova Regional" : "Editar Regional")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salvar") { saveAndClose() }
                    .disabled(nome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        
    }

    }

    private func prefillFromExistingIfNeeded() {
        guard !hasPrefilled else { return }
        if let regional {
            nome = regional.nome ?? ""
            endereco = regional.endereco ?? ""
            chefe = regional.chefe ?? ""
            ramal = regional.ramal ?? ""
        }
        hasPrefilled = true
    }

    private func fetchExistingRegional(byName name: String) -> RegionalInfo5? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.lowercased()
        let request = NSFetchRequest<RegionalInfo5>(entityName: "RegionalInfo5")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "(nome != nil) AND (lowercase_nome == %@) OR (lowercase(nome) == %@)", normalized, normalized)
        // Note: if there's no derived attribute `lowercase_nome`, the fallback `lowercase(nome)` will work.
        do {
            let results = try viewContext.fetch(request)
            return results.first
        } catch {
            print("[RegionalFormView] Fetch existing by name failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func save() throws {
        // Normalize inputs
        let trimmedNome = nome.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEndereco = endereco.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedChefe = chefe.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRamal = ramal.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate minimal requirement
        guard !trimmedNome.isEmpty else {
            throw NSError(domain: "RegionalFormView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Nome não pode ser vazio."])
        }

        // Determine target object: reuse if editing; if creating, try to find an existing with same normalized name
        let target: RegionalInfo5
        if let regional {
            target = regional
        } else if let existing = fetchExistingRegional(byName: trimmedNome) {
            target = existing
        } else {
            target = RegionalInfo5(context: viewContext)
        }

        // Assign values
        target.nome = trimmedNome
        target.endereco = trimmedEndereco
        target.chefe = trimmedChefe
        target.ramal = trimmedRamal

        // Persist
        try viewContext.save()
    }

    private func saveAndClose() {
        do {
            try save()
            onSaved?()
            dismiss()
        } catch {
            // In a production app, present an alert; for now, log the error
            print("[RegionalFormView] Erro ao salvar regional: \(error.localizedDescription)")
        }
    }

    #if DEBUG
    private func purgeAllRegionais() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        do {
            let result = try viewContext.persistentStoreCoordinator?.execute(deleteRequest, with: viewContext) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes: [AnyHashable: Any] = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
            }
            try viewContext.save()
            print("[RegionalFormView] Todas as regionais foram removidas.")
        } catch {
            print("[RegionalFormView] Falha ao limpar regionais: \(error.localizedDescription)")
        }
    }
    #endif
}

#Preview {
    let context = (try? PersistenceController.preview.container.viewContext) ?? NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    return NavigationStack {
        RegionalFormView(regional: nil)
            .environment(\.managedObjectContext, context)
    }
}
