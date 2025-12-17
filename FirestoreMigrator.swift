//
//  FirestoreMigrator.swift
//  ListaFuncionariosApp
//
//  Created by ChatGPT on 2025-12-04.
//  Totalmente reconstruído para segurança e estabilidade.
//
// NOTE: We mirror the Core Data UUID into Firestore field 'uuid' for stability and backward compatibility. DocumentID may differ or be legacy.

import Foundation
internal import CoreData
import FirebaseFirestore
import FirebaseStorage
import SDWebImage
import SDWebImageSwiftUI
import UIKit


struct FirestoreMigrator {

    // MARK: - Shared Instances
    private static var db: Firestore { Firestore.firestore() }
    private static var storage: StorageReference { Storage.storage().reference() }
    
    // Firestore structure (device-scoped by installID):
    // installids (collection)
    //  └─ {deviceID} (document)
    //      ├─ employees (subcollection of employee docs for this install)
    //      └─ municipios (subcollection of municipio docs for this install)
    // MARK: - Device-scoped paths
    private static var deviceID: String {
        // Per-install identifier: new UUID on first launch, persists in UserDefaults.
        // Deleting the app removes this ID, producing a new bucket on reinstall.
        let key = "FirestoreMigrator.InstallID"
        if let saved = UserDefaults.standard.string(forKey: key) {
            return saved
        }
        let gen = UUID().uuidString
        UserDefaults.standard.set(gen, forKey: key)
        return gen
    }

    private static var deviceDocument: DocumentReference {
        // Structure: installids/{deviceID}
        db.collection("installids").document(deviceID)
    }

    private static var employeesDeviceCollection: CollectionReference {
        // Structure: installids/{deviceID}/employees
        deviceDocument.collection("employees")
    }

    private static var municipiosDeviceCollection: CollectionReference {
        // Structure: installids/{deviceID}/municipios
        deviceDocument.collection("municipios")
    }

    // MARK: - Helpers
    private static func safeID(from raw: String) -> String {
        raw.replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - DELETE ALL DOCUMENTS (ASYNC) - USED BY AppDataResetter
    // MARK: --------------------------------------------------------------------

    static func deleteAllDocuments(in collectionName: String) async throws {
        let snapshot = try await db.collection(collectionName).getDocuments()
        let batch = db.batch()

        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { err in
                if let err = err {
                    continuation.resume(throwing: err)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
    // Wipe all employees (and their images) from Firestore for clean Xcode runs
    static func wipeFuncionariosInFirestore() async {
        do {
            // Delete device-scoped employees: employees/devices/{deviceID}
            let snapshot = try await employeesDeviceCollection.getDocuments()
            let batch = db.batch()
            for doc in snapshot.documents { batch.deleteDocument(doc.reference) }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                batch.commit { err in
                    if let err = err { continuation.resume(throwing: err) }
                    else { continuation.resume(returning: ()) }
                }
            }
            // Also remove all images in the employeeImages folder (best-effort)
            await wipeEmployeeImagesFolder()
            print("[Wipe] Firestore employees and images wiped.")
        } catch {
            print("[Wipe] Failed to wipe Firestore employees: \(error)")
        }
    }

    private static func wipeEmployeeImagesFolder() async {
        let storageRef = Storage.storage().reference().child("employeeImages/\(deviceID)")
        do {
            let result = try await storageRef.listAll()
            for item in result.items {
                do { try await item.delete() } catch { print("[Wipe] Failed to delete image: \(item.fullPath) -> \(error)") }
            }
        } catch {
            print("[Wipe] Failed to list employeeImages folder: \(error)")
        }
    }

    // Wipe all municipios for this device from Firestore for clean Xcode runs
    static func wipeMunicipiosInFirestore() async {
        do {
            let snapshot = try await municipiosDeviceCollection.getDocuments()
            let batch = db.batch()
            for doc in snapshot.documents { batch.deleteDocument(doc.reference) }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                batch.commit { err in
                    if let err = err { continuation.resume(throwing: err) }
                    else { continuation.resume(returning: ()) }
                }
            }
            print("[Wipe] Firestore municipios wiped.")
        } catch {
            print("[Wipe] Failed to wipe Firestore municipios: \(error)")
        }
    }

    // Download from Firestore to Core Data (including image)
    // We now do protective upserts to avoid duplicates when syncing.
    static func syncFromFirestoreToCoreData(context: NSManagedObjectContext, completion: @escaping (Result<Int, Error>) -> Void) {
        employeesDeviceCollection.getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                completion(.failure(error ?? NSError(domain: "Firestore", code: -1)))
                return
            }
            var updatedCount = 0
            let group = DispatchGroup()

            for doc in documents {
                group.enter()
                let data = doc.data()
                let idStr = (data["uuid"] as? String) ?? doc.documentID

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
                        // If Firestore doesn't provide a valid UUID, generate one and mirror it back
                        let newUUID = UUID()
                        funcionario.id = newUUID
                        // Persist back to Firestore for stability
                        employeesDeviceCollection.document(doc.documentID).setData(["uuid": newUUID.uuidString], merge: true)
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

                    // Upsert projetos from Firestore array
                    if let projetosArr = data["projetos"] as? [[String: Any]] {
                        // Build a map of existing projetos by (nome + status) as a simple key
                        let existing: [String: Projeto] = {
                            let set = (funcionario.value(forKey: "projetos") as? NSSet) ?? []
                            var dict: [String: Projeto] = [:]
                            for case let p as Projeto in set {
                                let key = "\(p.nome ?? "")|\(p.status ?? "")"
                                dict[key] = p
                            }
                            return dict
                        }()

                        var keep = Set<String>()

                        for projDict in projetosArr {
                            let nome = (projDict["nome"] as? String) ?? ""
                            let status = (projDict["status"] as? String) ?? ""
                            let desc = (projDict["descricao"] as? String)
                            let key = "\(nome)|\(status)"

                            let p = existing[key] ?? Projeto(context: context)
                            p.nome = nome
                            p.status = status
                            if let desc { p.setValue(desc, forKey: "descricao") }
                            p.funcionario = funcionario
                            keep.insert(key)
                        }

                        // Optionally delete local projetos not present in Firestore
                        if let set = funcionario.value(forKey: "projetos") as? NSSet {
                            for case let p as Projeto in set {
                                let key = "\(p.nome ?? "")|\(p.status ?? "")"
                                if !keep.contains(key) {
                                    context.delete(p)
                                }
                            }
                        }
                    }

                    updatedCount += 1

                    if let urlStr = imageURLString, let url = URL(string: urlStr) {
                        SDImageStorage.downloadImage(from: url) { result in
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
    // MARK: --------------------------------------------------------------------
    // MARK: - UPLOAD FUNCIONARIO (SAFE)
    // MARK: --------------------------------------------------------------------

    static func uploadFuncionario(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        context.perform {

            guard let funcionario = try? context.existingObject(with: objectID) as? Funcionario else {
                return completion(.failure(NSError(domain: "Migrator", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Funcionario not found"])))
            }

            guard let uuid = funcionario.id?.uuidString else {
                return completion(.failure(NSError(domain: "Migrator", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Funcionario missing UUID"])))
            }

            // Normalize display name: take the part after a vertical bar, similar to FuncionarioDetailView trimming
            let rawName = funcionario.nome ?? ""
            let displayNameClean: String = {
                let parts = rawName.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
                if let last = parts.last {
                    return String(last).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            }()

            var data: [String: Any] = [
                "uuid": uuid,
                "nome": funcionario.nome ?? "",
                "funcao": funcionario.funcao ?? "",
                "cargo": funcionario.funcao ?? "",
                "favorito": funcionario.favorito,
                "regional": funcionario.regional ?? "",
                "ramal": funcionario.ramal ?? "",
                "celular": funcionario.celular ?? "",
                "email": funcionario.email ?? "",
                "displayName": displayNameClean
            ]

            // Serialize projetos into Firestore-friendly array of dictionaries
            if let projetosSet = funcionario.value(forKey: "projetos") as? NSSet {
                let projetosArray: [[String: Any]] = projetosSet.compactMap { obj in
                    guard let p = obj as? Projeto else { return nil }
                    var dict: [String: Any] = [:]
                    dict["nome"] = p.nome ?? ""
                    dict["status"] = p.status ?? ""
                    if let desc = p.value(forKey: "descricao") as? String { dict["descricao"] = desc }
                    return dict
                }
                data["projetos"] = projetosArray
            }

            func finish() {
                employeesDeviceCollection.document(uuid).setData(data) { err in
                    if let err = err { completion(.failure(err)) }
                    else { completion(.success(())) }
                }
            }

            // Upload image if exists
            if let imageData = funcionario.imagem {
                let ref = storage.child("employeeImages/\(deviceID)/\(uuid).jpg")
                let meta = StorageMetadata()
                meta.contentType = "image/jpeg"

                ref.putData(imageData, metadata: meta) { _, err in
                    if let err = err {
                        print("[Migrator] Image upload failed: \(err)")
                        return finish()
                    }
                    ref.downloadURL { url, _ in
                        if let url = url { data["imageURL"] = url.absoluteString }
                        finish()
                    }
                }
                return
            }

            finish()
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - DELETE FUNCIONARIO (SAFE)
    // MARK: --------------------------------------------------------------------

    static func deleteFuncionario(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        context.perform {

            guard let funcionario = try? context.existingObject(with: objectID) as? Funcionario else {
                return completion(.failure(NSError(domain: "Migrator", code: -3,
                    userInfo: [NSLocalizedDescriptionKey: "Funcionario not found"])))
            }

            guard let uuid = funcionario.id?.uuidString else {
                return completion(.failure(NSError(domain: "Migrator", code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Missing UUID"])))
            }

            employeesDeviceCollection.document(uuid).delete { err in
                if let err = err { return completion(.failure(err)) }

                storage.child("employeeImages/\(deviceID)/\(uuid).jpg").delete { _ in }

                context.perform {
                    context.delete(funcionario)
                    do { try context.save(); completion(.success(())) }
                    catch { completion(.failure(error)) }
                }
            }
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - BULK MIGRATION FUNCIONARIOS (Core Data -> Firestore)
    // MARK: --------------------------------------------------------------------

    static func migrateFuncionariosToFirestore(
        from context: NSManagedObjectContext,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {

        context.perform {
            do {
                let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
                let funcionarios = try context.fetch(request)

                let group = DispatchGroup()
                var count = 0
                var finalError: Error?

                for f in funcionarios {
                    group.enter()
                    uploadFuncionario(objectID: f.objectID, context: context) { result in
                        switch result {
                        case .success: count += 1
                        case .failure(let e): finalError = e
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let err = finalError { completion(.failure(err)) }
                    else { completion(.success(count)) }
                }

            } catch {
                completion(.failure(error))
            }
        }
    }

    static func migrateFuncionariosToFirestoreAsync(
        from context: NSManagedObjectContext
    ) async throws -> Int {

        try await withCheckedThrowingContinuation { continuation in
            migrateFuncionariosToFirestore(from: context) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - SYNC FIRESTORE -> CORE DATA (FUNCIONARIOS)
    // MARK: --------------------------------------------------------------------

    static func syncFuncionariosFromFirestore(
        context: NSManagedObjectContext,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        employeesDeviceCollection.getDocuments { snapshot, err in
            guard let docs = snapshot?.documents, err == nil else {
                return completion(.failure(err ?? NSError()))
            }

            let group = DispatchGroup()
            var updated = 0

            for doc in docs {
                group.enter()

                let data = doc.data()
                let docID = doc.documentID
                let uuidString = (data["uuid"] as? String) ?? docID
                let uuid = UUID(uuidString: uuidString)

                context.perform {

                    let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()

                    if let uuid {
                        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                    } else {
                        let email = data["email"] as? String ?? ""
                        request.predicate = NSPredicate(format: "email == %@", email)
                    }

                    let existing = (try? context.fetch(request))?.first
                    let funcObj = existing ?? Funcionario(context: context)

                    if funcObj.id == nil {
                        if let uuid {
                            funcObj.id = uuid
                        } else {
                            // No valid UUID found; generate one and mirror it back to Firestore
                            let newUUID = UUID()
                            funcObj.id = newUUID
                            employeesDeviceCollection.document(docID).setData(["uuid": newUUID.uuidString], merge: true)
                        }
                    }

                    funcObj.nome = data["nome"] as? String
                    funcObj.funcao = data["funcao"] as? String
                    funcObj.regional = data["regional"] as? String
                    funcObj.celular = data["celular"] as? String
                    funcObj.ramal = data["ramal"] as? String
                    funcObj.email = data["email"] as? String
                    funcObj.favorito = data["favorito"] as? Bool ?? false

                    // Upsert projetos from Firestore array
                    if let projetosArr = data["projetos"] as? [[String: Any]] {
                        let existing: [String: Projeto] = {
                            let set = (funcObj.value(forKey: "projetos") as? NSSet) ?? []
                            var dict: [String: Projeto] = [:]
                            for case let p as Projeto in set {
                                let key = "\(p.nome ?? "")|\(p.status ?? "")"
                                dict[key] = p
                            }
                            return dict
                        }()

                        var keep = Set<String>()
                        for projDict in projetosArr {
                            let nome = (projDict["nome"] as? String) ?? ""
                            let status = (projDict["status"] as? String) ?? ""
                            let desc = (projDict["descricao"] as? String)
                            let key = "\(nome)|\(status)"

                            let p = existing[key] ?? Projeto(context: context)
                            p.nome = nome
                            p.status = status
                            if let desc { p.setValue(desc, forKey: "descricao") }
                            p.funcionario = funcObj
                            keep.insert(key)
                        }

                        if let set = funcObj.value(forKey: "projetos") as? NSSet {
                            for case let p as Projeto in set {
                                let key = "\(p.nome ?? "")|\(p.status ?? "")"
                                if !keep.contains(key) {
                                    context.delete(p)
                                }
                            }
                        }
                    }

                    if let urlStr = data["imageURL"] as? String,
                       let url = URL(string: urlStr) {

                        SDImageStorage.downloadImage(from: url) { result in
                            context.perform {
                                if case .success(let img) = result {
                                    funcObj.imagem = img
                                }
                                updated += 1
                                group.leave()
                            }
                        }
                    } else {
                        updated += 1
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                context.perform {
                    do { try context.save(); completion(.success(updated)) }
                    catch { completion(.failure(error)) }
                }
            }
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - MUNICIPIOS (device-scoped: municipios/devices/{deviceID})
    // MARK: --------------------------------------------------------------------

    static func uploadMunicipio(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        context.perform {

            guard let municipio = try? context.existingObject(with: objectID) as? Municipio else {
                return completion(.failure(NSError(domain: "Migrator", code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Municipio not found"])))
            }

            guard let uuid = municipio.id as? UUID else {
                return completion(.failure(NSError(domain: "Migrator", code: -11,
                    userInfo: [NSLocalizedDescriptionKey: "Municipio missing UUID"])))
            }

            let docId = uuid.uuidString

            let data: [String: Any] = [
                "uuid": docId,
                "nome": municipio.nome ?? "",
                "regional": municipio.regional ?? "",
                "favorito": municipio.favorito
            ]

            municipiosDeviceCollection.document(docId).setData(data) { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(())) }
            }
        }
    }

    static func deleteMunicipio(
        objectID: NSManagedObjectID,
        context: NSManagedObjectContext,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {

        context.perform {

            guard let municipio = try? context.existingObject(with: objectID) as? Municipio else {
                return completion(.failure(NSError(domain: "Migrator", code: -12,
                    userInfo: [NSLocalizedDescriptionKey: "Municipio not found"])))
            }

            guard let uuid = municipio.id as? UUID else {
                return completion(.failure(NSError(domain: "Migrator", code: -13,
                    userInfo: [NSLocalizedDescriptionKey: "Missing UUID"])))
            }

            let docId = uuid.uuidString

            municipiosDeviceCollection.document(docId).delete { err in
                if let err = err { return completion(.failure(err)) }

                context.perform {
                    context.delete(municipio)
                    do { try context.save(); completion(.success(())) }
                    catch { completion(.failure(error)) }
                }
            }
        }
    }

    /// Updates the favorito flag for a Municipio both locally and in Firestore.
    /// Prints a detail log on success so you can verify in the console.
    static func updateMunicipioFavorito(
        objectID: NSManagedObjectID,
        favorito: Bool,
        context: NSManagedObjectContext,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        context.perform {
            guard let municipio = try? context.existingObject(with: objectID) as? Municipio else {
                completion?(.failure(NSError(domain: "Migrator", code: -14, userInfo: [NSLocalizedDescriptionKey: "Municipio not found"])));
                return
            }

            guard let uuid = (municipio.id as? UUID) ?? (municipio.id as? NSUUID as UUID?) else {
                completion?(.failure(NSError(domain: "Migrator", code: -15, userInfo: [NSLocalizedDescriptionKey: "Missing Municipio UUID"])));
                return
            }

            // Update local first
            municipio.favorito = favorito

            do { try context.save() } catch {
                completion?(.failure(error));
                return
            }

            // Push to Firestore (device scoped) and log on success
            let docId = uuid.uuidString
            municipiosDeviceCollection.document(docId).setData(["favorito": favorito, "uuid": docId], merge: true) { err in
                if let err = err {
                    completion?(.failure(err))
                } else {
                    print("[Detail] Municipio (\(docId)) - Favorito atualizado")
                    completion?(.success(()))
                }
            }
        }
    }

    // MARK: - SYNC MUNICIPIOS FROM FIRESTORE

    static func syncMunicipiosFromFirestore(
        context: NSManagedObjectContext,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {

        municipiosDeviceCollection.getDocuments { snapshot, err in
            guard let docs = snapshot?.documents, err == nil else {
                return completion(.failure(err ?? NSError()))
            }

            let group = DispatchGroup()
            var updated = 0

            for doc in docs {
                group.enter()

                let data = doc.data()
                let docId = doc.documentID
                let uuidString = (data["uuid"] as? String) ?? docId
                let uuid = UUID(uuidString: uuidString)

                context.perform {

                    let request: NSFetchRequest<Municipio> = Municipio.fetchRequest()

                    if let uuid {
                        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
                    } else {
                        let nome = data["nome"] as? String ?? ""
                        request.predicate = NSPredicate(format: "nome == %@", nome)
                    }

                    let existing = (try? context.fetch(request))?.first
                    let municipio = existing ?? Municipio(context: context)

                    if municipio.id == nil {
                        if let uuid {
                            municipio.id = uuid as NSUUID as UUID
                        } else {
                            let newUUID = UUID()
                            municipio.id = newUUID as NSUUID as UUID
                            municipiosDeviceCollection.document(docId).setData(["uuid": newUUID.uuidString], merge: true)
                        }
                    }

                    municipio.nome = data["nome"] as? String
                    municipio.regional = data["regional"] as? String
                    municipio.favorito = data["favorito"] as? Bool ?? false

                    updated += 1
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                context.perform {
                    do { try context.save(); completion(.success(updated)) }
                    catch { completion(.failure(error)) }
                }
            }
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - BULK MIGRATION MUNICIPIOS (Core Data -> Firestore)
    // MARK: --------------------------------------------------------------------

    static func migrateMunicipiosToFirestore(
        from context: NSManagedObjectContext,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {

        context.perform {
            do {
                let request: NSFetchRequest<Municipio> = Municipio.fetchRequest()
                let municipios = try context.fetch(request)

                let group = DispatchGroup()
                var count = 0
                var finalError: Error?

                for m in municipios {
                    group.enter()
                    uploadMunicipio(objectID: m.objectID, context: context) { result in
                        switch result {
                        case .success: count += 1
                        case .failure(let e): finalError = e
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    if let err = finalError { completion(.failure(err)) }
                    else { completion(.success(count)) }
                }

            } catch {
                completion(.failure(error))
            }
        }
    }

    static func migrateMunicipiosToFirestoreAsync(
        from context: NSManagedObjectContext
    ) async throws -> Int {

        try await withCheckedThrowingContinuation { continuation in
            migrateMunicipiosToFirestore(from: context) { result in
                continuation.resume(with: result)
            }
        }
    }
    
    // MARK: --------------------------------------------------------------------
    // MARK: - HOUSEKEEPING: PURGE UNNAMED FUNCIONARIOS
    // MARK: --------------------------------------------------------------------

    /// Deletes any Funcionario rows whose `nome` is exactly "(Sem nome)".
    /// Call this before fetching to ensure the list doesn't show placeholder entries.
    /// - Parameters:
    ///   - context: The NSManagedObjectContext to operate on.
    ///   - completion: Completion with the number of deleted rows or an error.
    static func purgeUnnamedFuncionarios(
        context: NSManagedObjectContext,
        completion: @escaping (Result<Int, Error>) -> Void
    ) {
        context.perform {
            do {
                let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
                request.predicate = NSPredicate(format: "nome == nil OR nome == '' OR nome == %@", "(Sem nome)")
                let results = try context.fetch(request)
                let deleteCount = results.count

                for obj in results { context.delete(obj) }
                if context.hasChanges { try context.save() }

                completion(.success(deleteCount))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Async/await convenience wrapper for purging unnamed funcionarios.
    @discardableResult
    static func purgeUnnamedFuncionariosAsync(
        context: NSManagedObjectContext
    ) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            purgeUnnamedFuncionarios(context: context) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - SDWebImage-backed image storage helper
    fileprivate enum SDImageStorage {
        static func downloadImage(from url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
            // Use a shared URL cache-aware session
            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .returnCacheDataElseLoad
            config.urlCache = URLCache.shared
            let session = URLSession(configuration: config)

            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad

            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let data = data, !data.isEmpty {
                    // If the server returned image bytes, pass them through
                    completion(.success(data))
                    return
                }
                // As a fallback, try to construct image data from response if possible (no external frameworks)
                completion(.failure(NSError(domain: "SDImageStorage", code: -2, userInfo: [NSLocalizedDescriptionKey: "No image data received"])) )
            }
            task.resume()
        }
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - HOUSEKEEPING: SANITIZE EMPLOYEES ROOT (keep only 'devices')
    // MARK: --------------------------------------------------------------------

    /// Ensures the Firestore collection `employees` contains only the document `devices` at its root.
    /// Deletes any stray documents with random IDs that may have been created by legacy code.
    /// - Parameter completion: Result with number of deleted docs or an error.
    static func sanitizeEmployeesRoot(completion: @escaping (Result<Int, Error>) -> Void) {
        let employeesRoot = db.collection("employees")
        employeesRoot.getDocuments { snapshot, error in
            if let error = error {
                return completion(.failure(error))
            }
            guard let docs = snapshot?.documents else {
                return completion(.success(0))
            }

            let batch = db.batch()
            var deleteCount = 0

            for doc in docs {
                if doc.documentID != "devices" {
                    batch.deleteDocument(doc.reference)
                    deleteCount += 1
                }
            }

            if deleteCount == 0 {
                return completion(.success(0))
            }

            batch.commit { err in
                if let err = err { completion(.failure(err)) }
                else { completion(.success(deleteCount)) }
            }
        }
    }

    /// Async/await variant of sanitizeEmployeesRoot.
    @discardableResult
    static func sanitizeEmployeesRootAsync() async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            sanitizeEmployeesRoot { result in
                continuation.resume(with: result)
            }
        }
    }

    /// Helper to expose a Municipio's UUID as String for UI (Details view)
    static func municipioUUIDString(_ municipio: Municipio) -> String? {
        if let u = municipio.id as? UUID { return u.uuidString }
        if let u = municipio.id as? NSUUID { return (u as UUID).uuidString }
        return nil
    }

    // MARK: --------------------------------------------------------------------
    // MARK: - STARTUP SCHEDULER: DELAYED SANITIZATION
    // MARK: --------------------------------------------------------------------

    /// Schedules a one-time sanitization of the employees root a few seconds after app start.
    /// Use this after you kick off your initial migrations/population so stray legacy docs
    /// that appear slightly later can be cleaned up.
    /// - Parameter delaySeconds: How long to wait before running. Default 8 seconds.
    static func schedulePostStartupSanitization(delaySeconds: TimeInterval = 8) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) {
            Task {
                do {
                    let removed = try await sanitizeEmployeesRootAsync()
                    if removed > 0 {
                        print("[Sanitize] Removed stray employees root docs: \(removed)")
                    } else {
                        print("[Sanitize] No stray employees root docs found.")
                    }
                } catch {
                    print("[Sanitize] Failed to sanitize employees root: \(error)")
                }
            }
        }
    }
}

