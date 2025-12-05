import Foundation
internal import CoreData
import FirebaseFirestore
import FirebaseStorage

struct FirestoreMigrator {
    // Firestore document IDs must not contain '/'. This helper creates a safe ID from any string.
    private static func firestoreSafeID(from raw: String) -> String {
        // Replace all '/' with '_' and remove spaces
        let replaced = raw.replacingOccurrences(of: "/", with: "_")
        // Firestore allows most characters; keep it simple and trim whitespace
        return replaced.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - DELETE HELPERS
    // Delete a single Funcionario in Firestore (employees collection) and Core Data. Also removes image from Storage if present.
    static func deleteFuncionario(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        context.perform {
            do {
                guard let funcionario = try context.existingObject(with: objectID) as? Funcionario else {
                    completion(.failure(NSError(domain: "FirestoreMigrator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Funcionario not found for objectID"])));
                    return
                }

                // Compute Firestore document id (we use the UUID stored in Core Data for employees)
                guard let id = funcionario.id?.uuidString else {
                    // If no UUID is present, fall back to objectID URI (sanitized), but also delete locally to avoid dangling records
                    let fallbackId = firestoreSafeID(from: objectID.uriRepresentation().absoluteString)
                    let db = Firestore.firestore()
                    db.collection("employees").document(fallbackId).delete { _ in }
                    context.delete(funcionario)
                    do { try context.save(); completion(.success(())) } catch { completion(.failure(error)) }
                    return
                }

                let db = Firestore.firestore()
                let storageRef = Storage.storage().reference().child("employeeImages/\(id).jpg")

                // First try to delete Firestore document
                db.collection("employees").document(id).delete { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }

                    // Try to delete image from Storage (ignore errors to not block local deletion)
                    storageRef.delete { _ in
                        // Now delete from Core Data
                        context.perform {
                            context.delete(funcionario)
                            do { try context.save(); completion(.success(())) } catch { completion(.failure(error)) }
                        }
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // Delete a single Municipio in Firestore (municipios collection) and Core Data.
    static func deleteMunicipio(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        context.perform {
            do {
                guard let municipio = try context.existingObject(with: objectID) as? Municipio else {
                    completion(.failure(NSError(domain: "FirestoreMigrator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Municipio not found for objectID"])));
                    return
                }

                // Determine Firestore doc id: prefer UUID if available; else sanitized objectID URI
                let docId: String
                if let uuid = municipio.id as? UUID {
                    docId = uuid.uuidString
                } else {
                    docId = firestoreSafeID(from: objectID.uriRepresentation().absoluteString)
                }

                let db = Firestore.firestore()
                db.collection("municipios").document(docId).delete { error in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    // Delete from Core Data after Firestore
                    context.perform {
                        context.delete(municipio)
                        do { try context.save(); completion(.success(())) } catch { completion(.failure(error)) }
                    }
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func migrateFuncionariosToFirestore(from context: NSManagedObjectContext, completion: @escaping (Result<Int, Error>) -> Void) {
        let fetchRequest: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        do {
            let funcionarios = try context.fetch(fetchRequest)
            let db = Firestore.firestore()
            let group = DispatchGroup()
            var migratedCount = 0
            var lastError: Error?

            for funcionario in funcionarios {
                group.enter()
                var data: [String: Any] = [
                    "nome": funcionario.nome ?? "",
                    // Persist both keys for backward compatibility with existing Firestore docs
                    "funcao": funcionario.funcao ?? "",
                    "cargo": funcionario.funcao ?? "",
                    "favorito": funcionario.favorito,
                    "regional": funcionario.regional ?? "",
                    "ramal": funcionario.ramal ?? "",
                    "celular": funcionario.celular ?? "",
                    "email": funcionario.email ?? ""
                ]
                if let imageData = funcionario.imagem,
                   let id = funcionario.id?.uuidString {
                    uploadImage(imageData, for: id) { result in
                        switch result {
                        case .success(let url):
                            data["imageURL"] = url.absoluteString
                        case .failure(let error):
                            print("[FirestoreMigrator] Image upload failed: \(error)")
                        }
                        saveFuncionario(db: db, funcionario: funcionario, data: data) {
                            migratedCount += 1
                            group.leave()
                        }
                    }
                } else {
                    saveFuncionario(db: db, funcionario: funcionario, data: data) {
                        migratedCount += 1
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                if let lastError = lastError {
                    completion(.failure(lastError))
                } else {
                    completion(.success(migratedCount))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    static func migrateMunicipiosToFirestore(from context: NSManagedObjectContext, completion: @escaping (Result<Int, Error>) -> Void) {
        let fetchRequest: NSFetchRequest<Municipio> = Municipio.fetchRequest()

        do {
            let municipios = try context.fetch(fetchRequest)
            let db = Firestore.firestore()
            let group = DispatchGroup()
            var migratedCount = 0
            var lastError: Error?

            for municipio in municipios {
                group.enter()

                var data: [String: Any] = [
                    "nome": municipio.nome ?? "",
                    "regional": municipio.regional ?? "",
                    "favorito": municipio.favorito
                ]

                let docId: String
                if let uuid = municipio.id as? UUID {
                    docId = uuid.uuidString
                } else {
                    // Stable fallback using Core Data objectID URI, sanitized for Firestore
                    let uriString = municipio.objectID.uriRepresentation().absoluteString
                    docId = firestoreSafeID(from: uriString)
                }

                db.collection("municipios").document(docId).setData(data) { err in
                    if let err = err {
                        lastError = err
                    } else {
                        migratedCount += 1
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                if let lastError = lastError {
                    completion(.failure(lastError))
                } else {
                    completion(.success(migratedCount))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    // Upload a single Funcionario change to Firestore
    static func uploadFuncionario(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Fetch the Funcionario from Core Data using the provided objectID
        do {
            guard let funcionario = try context.existingObject(with: objectID) as? Funcionario else {
                completion(.failure(NSError(domain: "FirestoreMigrator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Funcionario not found for objectID"])))
                return
            }

            let db = Firestore.firestore()

            // Prepare base data (always mirror Core Data fields)
            var data: [String: Any] = [
                "nome": funcionario.nome ?? "",
                "funcao": funcionario.funcao ?? "",
                "cargo": funcionario.funcao ?? "", // backward compatibility
                "favorito": funcionario.favorito,
                "regional": funcionario.regional ?? "",
                "ramal": funcionario.ramal ?? "",
                "celular": funcionario.celular ?? "",
                "email": funcionario.email ?? ""
            ]

            // Helper to save the document after optional image upload
            func finishSave() {
                Self.saveFuncionario(db: db, funcionario: funcionario, data: data) {
                    completion(.success(()))
                }
            }

            // If there's inline image data, upload to Storage first to get URL
            if let imageData = funcionario.imagem, let id = funcionario.id?.uuidString {
                Self.uploadImage(imageData, for: id) { result in
                    switch result {
                    case .success(let url):
                        data["imageURL"] = url.absoluteString
                        finishSave()
                    case .failure(let error):
                        // Log the error but still proceed with saving other fields
                        print("[FirestoreMigrator] Image upload failed for single upload: \(error)")
                        finishSave()
                    }
                }
            } else {
                // No image to upload
                finishSave()
            }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Async helpers
    static func deleteAllDocuments(in collectionName: String) async throws {
        let db = Firestore.firestore()
        let snapshot = try await db.collection(collectionName).getDocuments()
        let batch = db.batch()

        for document in snapshot.documents {
            batch.deleteDocument(document.reference)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    // Wipe all employees (and their images) from Firestore for clean Xcode runs
    static func wipeFuncionariosInFirestore() async {
        do {
            try await deleteAllDocuments(in: "employees")
            // Also remove all images in the employeeImages folder (best-effort)
            await wipeEmployeeImagesFolder()
            print("[Wipe] Firestore employees and images wiped.")
        } catch {
            print("[Wipe] Failed to wipe Firestore employees: \(error)")
        }
    }

    private static func wipeEmployeeImagesFolder() async {
        let storageRef = Storage.storage().reference().child("employeeImages")
        do {
            let result = try await storageRef.listAll()
            for item in result.items {
                do { try await item.delete() } catch { print("[Wipe] Failed to delete image: \(item.fullPath) -> \(error)") }
            }
        } catch {
            print("[Wipe] Failed to list employeeImages folder: \(error)")
        }
    }

    static func migrateFuncionariosToFirestoreAsync(from context: NSManagedObjectContext) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            migrateFuncionariosToFirestore(from: context) { result in
                continuation.resume(with: result)
            }
        }
    }

    static func migrateMunicipiosToFirestoreAsync(from context: NSManagedObjectContext) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            migrateMunicipiosToFirestore(from: context) { result in
                continuation.resume(with: result)
            }
        }
    }

    // Upload a single Municipio change to Firestore
    static func uploadMunicipio(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            guard let municipio = try context.existingObject(with: objectID) as? Municipio else {
                completion(.failure(NSError(domain: "FirestoreMigrator", code: -1, userInfo: [NSLocalizedDescriptionKey: "Municipio not found for objectID"])))
                return
            }

            let db = Firestore.firestore()

            var data: [String: Any] = [
                "nome": municipio.nome ?? "",
                "regional": municipio.regional ?? "",
                "favorito": municipio.favorito
            ]

            let docId: String
            if let uuid = municipio.id as? UUID {
                docId = uuid.uuidString
            } else {
                let uriString = objectID.uriRepresentation().absoluteString
                docId = firestoreSafeID(from: uriString)
            }

            db.collection("municipios").document(docId).setData(data) { err in
                if let err = err {
                    completion(.failure(err))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private static func saveFuncionario(db: Firestore, funcionario: Funcionario, data: [String: Any], finished: @escaping () -> Void) {
        guard let id = funcionario.id?.uuidString else { finished(); return }
        db.collection("employees").document(id).setData(data) { err in
            if let err = err {
                print("[FirestoreMigrator] Error writing doc: \(err)")
            }
            finished()
        }
    }

    private static func uploadImage(_ imageData: Data, for id: String, completion: @escaping (Result<URL, Error>) -> Void) {
        let storageRef = Storage.storage().reference().child("employeeImages/\(id).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        storageRef.putData(imageData, metadata: metadata) { meta, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            storageRef.downloadURL { url, error in
                if let url = url {
                    completion(.success(url))
                } else if let error = error {
                    completion(.failure(error))
                }
            }
        }
    }

    // Download from Firestore to Core Data (including image)
    // We now do protective upserts to avoid duplicates when syncing.
    static func syncFromFirestoreToCoreData(context: NSManagedObjectContext, completion: @escaping (Result<Int, Error>) -> Void) {
        let db = Firestore.firestore()
        db.collection("employees").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                completion(.failure(error ?? NSError(domain: "Firestore", code: -1)))
                return
            }
            var updatedCount = 0
            let group = DispatchGroup()

            for doc in documents {
                group.enter()
                let data = doc.data()
                let idStr = doc.documentID

                context.perform {
                    // Normalize document ID to a UUID when possible
                    let uuidFromDoc = UUID(uuidString: idStr)

                    // Try to find an existing Funcionario by UUID id
                    let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
                    if let uuid = uuidFromDoc {
                        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                    } else {
                        // If doc ID is not a UUID, search by a secondary unique key (imageURL) to avoid duplicates
                        // Note: Adjust this if you have a different unique key strategy
                        if let imageURL = (data["imageURL"] as? String) ?? (data["imagemURL"] as? String) {
                            request.predicate = NSPredicate(format: "imagemURL == %@", imageURL)
                        } else {
                            // Fallback: match by name + email (less reliable but prevents rampant duplication)
                            let nome = (data["nome"] as? String) ?? ""
                            let email = (data["email"] as? String) ?? ""
                            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                                NSPredicate(format: "nome == %@", nome),
                                NSPredicate(format: "email == %@", email)
                            ])
                        }
                    }

                    let existing = (try? context.fetch(request))?.first
                    let funcionario = existing ?? Funcionario(context: context)

                    // Ensure we set a stable UUID id if possible
                    if let uuid = uuidFromDoc {
                        funcionario.id = uuid
                    } else if funcionario.id == nil {
                        // If Firestore doc id is not a UUID and the local record has no id yet, assign one
                        funcionario.id = UUID()
                    }

                    // Set fields after finding or creating the record
                    funcionario.nome = data["nome"] as? String
                    funcionario.funcao = (data["funcao"] as? String) ?? (data["cargo"] as? String)
                    funcionario.ramal = data["ramal"] as? String
                    funcionario.celular = data["celular"] as? String
                    funcionario.email = data["email"] as? String
                    funcionario.favorito = data["favorito"] as? Bool ?? false
                    funcionario.regional = data["regional"] as? String

                    let imageURLString = (data["imageURL"] as? String) ?? (data["imagemURL"] as? String)
                    funcionario.imagemURL = imageURLString
                    updatedCount += 1

                    if let urlStr = imageURLString, let url = URL(string: urlStr) {
                        ImageStorage.downloadImage(from: url) { result in
                            context.perform {
                                if case .success(let imageData) = result {
                                    funcionario.imagem = imageData
                                }
                                group.leave()
                            }
                        }
                    } else {
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                context.perform {
                    do {
                        try context.save()
                        completion(.success(updatedCount))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
}

