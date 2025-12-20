//
//  Untitled.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 20/12/25.
//

internal import CoreData
internal import FirebaseFirestoreInternal
extension FirestoreMigrator {

static func syncInfoRegionaisFromFirestore(
    context: NSManagedObjectContext,
    completion: @escaping (Result<Int, Error>) -> Void
) {
    inforegionaisDeviceCollection.getDocuments { snapshot, error in
        guard let docs = snapshot?.documents, error == nil else {
            completion(.failure(error ?? NSError(domain: "Firestore", code: -1)))
            return
        }

        context.perform {
            var updated = 0
            var seenKeys = Set<String>()

            // Pass 1: Upsert and wipe duplicates per incoming doc
            for doc in docs {
                let data = doc.data()

                let nomeVal = (data["nome"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let ramalVal = (data["ramal"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let key = "\(nomeVal.lowercased())|\(ramalVal.lowercased())"

                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
                if !ramalVal.isEmpty {
                    fetch.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "nome == %@", nomeVal),
                        NSPredicate(format: "ramal == %@", ramalVal)
                    ])
                } else {
                    fetch.predicate = NSPredicate(format: "nome == %@", nomeVal)
                }

                var target: NSManagedObject?
                do {
                    let matches = try context.fetch(fetch) as? [NSManagedObject] ?? []
                    if let first = matches.first {
                        target = first
                        // Delete duplicates beyond the first
                        if matches.count > 1 {
                            for dup in matches.dropFirst() {
                                context.delete(dup)
                            }
                        }
                    } else {
                        target = NSEntityDescription.insertNewObject(forEntityName: "RegionalInfo5", into: context)
                    }
                } catch {
                    // On fetch failure, still create a new object to not block the sync
                    target = NSEntityDescription.insertNewObject(forEntityName: "RegionalInfo5", into: context)
                }

                if let regional = target {
                    if !nomeVal.isEmpty { regional.setValue(nomeVal, forKey: "nome") }
                    if let chefe = data["chefe"] as? String { regional.setValue(chefe, forKey: "chefe") }
                    if !ramalVal.isEmpty { regional.setValue(ramalVal, forKey: "ramal") }
                    if let endereco = data["endereco"] as? String { regional.setValue(endereco, forKey: "endereco") }
                }

                seenKeys.insert(key)
                updated += 1
            }

            // Pass 2: Global duplicate cleanup across existing Core Data, keep first per key
            do {
                let allFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")
                let all = try context.fetch(allFetch) as? [NSManagedObject] ?? []
                var keeperByKey: [String: NSManagedObject] = [:]

                for obj in all {
                    let nome = (obj.value(forKey: "nome") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    let ramal = (obj.value(forKey: "ramal") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    let k = "\(nome)|\(ramal)"
                    if keeperByKey[k] == nil {
                        keeperByKey[k] = obj
                    } else {
                        context.delete(obj)
                    }
                }
            } catch {
                // Ignore cleanup errors; proceed to save what we can
            }

            do {
                if context.hasChanges {
                    try context.save()
                }
                completion(.success(updated))
            } catch {
                completion(.failure(error))
            }
        }
    }
}

    
}
