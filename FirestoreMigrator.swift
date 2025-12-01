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
    // end uploadMunicipio

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
                    let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", UUID(uuidString: idStr) as CVarArg? ?? "")
                    let funcionario = (try? context.fetch(request))?.first ?? Funcionario(context: context)
                    funcionario.id = UUID(uuidString: idStr) ?? UUID()
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
