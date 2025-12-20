//
//  FuncionarioViewModel.swift
//  ListaFuncionariosApp
//
//  Created by Matheus Braschi Haliski on 04/08/25.
//

import Foundation
internal import CoreData
import SwiftUI
import FirebaseFirestore
import FirebaseCore
import Combine

@MainActor
final class FuncionarioViewModel: ObservableObject {
    // A stable identifier for this app installation (persists across launches, changes on reinstall)
    static let installID: String = {
        let key = "app.install.id"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()

    // Tracks whether we've seeded funcionarios for this specific installation already
    private static let seededKey = "app.install.seeded.funcionarios"

    let objectWillChange = ObservableObjectPublisher()
    
    @Published var funcionarios: [Funcionario] = []

    private var context: NSManagedObjectContext

    init() {
        self.objectWillChange.send() // optional early signal; harmless
        self.context = PersistenceController.shared.container.viewContext
        seedFuncionariosForThisInstallIfNeeded()
        // Defer fetch until after initialization completes
        Task { [weak self] in
            await MainActor.run {
                self?.fetchFuncionarios()
            }
        }
    }

    init(context: NSManagedObjectContext) {
        self.objectWillChange.send() // optional early signal; harmless
        self.context = context
        seedFuncionariosForThisInstallIfNeeded()
        Task { [weak self] in
            await MainActor.run {
                self?.fetchFuncionarios()
            }
        }
    }

    // Injects a context coming from the SwiftUI environment
    // and immediately refetches using the new context
    func setManagedObjectContext(_ context: NSManagedObjectContext) {
        self.context = context
        fetchFuncionarios()
    }

    /// Seeds a fresh set of funcionarios for this installation only once.
    /// This ensures every install gets its own unique UUIDs for each preloaded Funcionario,
    /// enabling per-device favorites and state.
    private func seedFuncionariosForThisInstallIfNeeded() {
        let seeded = UserDefaults.standard.bool(forKey: Self.seededKey)
        guard seeded == false else { return }

        // Build the baseline dataset by calling the regional population helpers.
        // These helpers already create new Funcionario with fresh UUIDs.
        // We run them unconditionally on first launch of this installation.
        popularNucleos(context: context)

        // Persist the flag so we don't reseed on every app launch, only per install.
        UserDefaults.standard.set(true, forKey: Self.seededKey)

        // Optionally: annotate each newly created Funcionario with this install ID via a transient field if you have one.
        // If you later upload to Firestore, you can include `deviceInstallId: Self.installID`.
    }

    func fetchFuncionarios() {
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        // Filter to only show the instances created for this installation
        request.predicate = NSPredicate(format: "nome BEGINSWITH %@", Self.installID + " | ")
        do {
            funcionarios = try context.fetch(request)
        } catch {
            print("Erro ao buscar funcionários: \(error.localizedDescription)")
        }
    }

    func adicionarFuncionario(nome: String, funcao: String, ramal: String, celular: String, email: String, regional: String) {
        let novo = Funcionario(context: context)
        novo.nome = nome
        novo.funcao = funcao
        novo.ramal = ramal
        novo.celular = celular
        novo.email = email
        novo.regional = regional
        salvar()
    }

    func deletarFuncionario(_ funcionario: Funcionario) {
        context.delete(funcionario)
        salvar()
    }

    func salvar() {
        do {
            try context.save()
            fetchFuncionarios()
        } catch {
            print("Erro ao salvar contexto: \(error.localizedDescription)")
        }
    }

    /// Resets all funcionarios to default mode, preserving only `nome` and `regional`.
    /// Other fields (funcao, ramal, celular, email, imagemURL, imagem) are cleared.
    /// Also mirrors the reset in Firestore for collection "employees".
    func resetToDefaultMode() {
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        do {
            let all = try context.fetch(request)
            // 1) Core Data reset
            for funcionario in all {
                funcionario.funcao = ""
                funcionario.ramal = ""
                funcionario.celular = ""
                funcionario.email = ""
                funcionario.imagemURL = nil
                funcionario.imagem = nil
            }
            try context.save()
            fetchFuncionarios()

            // 2) Firestore reset (best-effort, async)
            Task {
                let db = Firestore.firestore()
                let collection = db.collection("employees")
                let batch = db.batch()

                // We'll try to match documents by a stable identifier when available.
                // Prefer Core Data UUID `id` field when present, otherwise fall back to name match.
                // If falling back to name, multiple docs can match; we will update all with that name.
                // Note: Adjust field keys here if your Firestore schema differs.

                do {
                    // Preload all employee docs if we need name-based fallback
                    let snapshot = try await collection.getDocuments()

                    for funcionario in all {
                        let cleared: [String: Any] = [
                            "funcao": "",
                            "ramal": "",
                            "celular": "",
                            "email": "",
                            "imagemURL": NSNull(),
                            "imagem": NSNull(),
                            "deviceInstallId": FuncionarioViewModel.installID
                        ]

                        if let uuid = funcionario.id?.uuidString, !uuid.isEmpty {
                            // Use document with id == uuid if it exists, otherwise create/merge
                            let docRef = collection.document(uuid)
                            batch.setData(cleared, forDocument: docRef, merge: true)
                        } else {
                            // Fallback by name: update all docs whose `nome` equals this funcionario name
                            let nome = (funcionario.nome ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !nome.isEmpty else { continue }

                            let matching = snapshot.documents.filter { doc in
                                let docName = (doc.data()["nome"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                return docName == nome
                            }
                            for doc in matching {
                                batch.setData(cleared, forDocument: doc.reference, merge: true)
                            }
                        }
                    }

                    try await batch.commit()
                    print("✅ Firestore employees reset to default mode to mirror Core Data.")
                } catch {
                    print("❌ Failed to mirror reset in Firestore: \(error)")
                }
            }

            print("✅ All funcionarios reset to default mode (only nome and regional preserved).")
        } catch {
            print("❌ Failed to reset funcionarios to default mode: \(error)")
        }
    }

}
// MARK: - Maintenance: Remove Firestore Duplicates by Name
/// Removes duplicate funcionario documents in Firestore by grouping on the "nome" field.
/// This version does NOT rely on `updatedAt`. It simply keeps the first document encountered
/// for each unique name and deletes the rest.
func removeDuplicateEmployeesByName() async {
    let db = Firestore.firestore()
    let collection = db.collection("employees")

    do {
        let snapshot = try await collection.getDocuments()
        print("[Duplicates] Total documents loaded: \(snapshot.documents.count)")

        var seenNames = Set<String>()
        var deletedCount = 0
        var duplicatesGroups = 0

        // Grouping by name without timestamps: we will keep the first occurrence we encounter
        // and delete subsequent documents that have the same name.
        for doc in snapshot.documents {
            let data = doc.data()
            let name = (data["nome"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !name.isEmpty else { continue }

            if seenNames.contains(name) {
                // Duplicate found: delete it
                do {
                    try await doc.reference.delete()
                    deletedCount += 1
                } catch {
                    print("[Duplicates] ❌ Failed to delete doc \(doc.documentID) for name \(name): \(error)")
                }
            } else {
                // First time we see this name
                seenNames.insert(name)
            }
        }

        // Rough count of groups with duplicates equals total unique names where count > 1.
        // Since we did a single pass, we can approximate by subtracting unique names from total docs.
        duplicatesGroups = max(0, snapshot.documents.count - seenNames.count)

        print("[Duplicates] ✅ Done. Groups with duplicates (approx): \(duplicatesGroups). Total deleted: \(deletedCount)")
    } catch {
        print("[Duplicates] ❌ Error loading documents: \(error)")
    }
}
extension FuncionarioViewModel {
    
    func popularNucleos(context: NSManagedObjectContext) {
        popularNucleoCuritiba(context: context)
        popularNucleoPontaGrossa(context: context)
        popularNucleoUniaoDaVitoria(context: context)
        popularNucleoLondrina(context: context)
        popularNucleoSantoAntonio(context: context)
        popularNucleoCascavel(context: context)
        popularNucleoMaringa(context: context)
        popularNucleoPatoBranco(context: context)
        popularNucleoCampoMourao(context: context)
        popularNucleoGuarapuava(context: context)
        popularNucleoUmuarama(context: context)
        popularRegionaisInfo(context: context)
    }

    // MARK: - CURITIBA
    func popularNucleoCuritiba(context: NSManagedObjectContext) {
        popularNucleo(
            nomeRegional: "Curitiba",
            lista: [
                ("Cíntia Aparecida de Lima", "Chefe"),
                ("Amauri Romão da Silva", nil),
                ("Camila Castanha", nil),
                ("Luiz Carlos Geremias Junior", nil),
                ("Zenon Silvério Neto", nil),
                ("Hugo Demay Hoecklerner", nil),
                ("Ricardo Barreira", nil),
                ("Luís César Moro", nil),
                ("Tatiane Macedo Motta", nil),
                ("Andréia Pichonelli", nil),
                ("Mayra Camila Wrobel dos Santos", nil),
                ("Matheus Braschi Haliski", nil)
            ],
            context: context
        )
    }

    // MARK: - PONTA GROSSA
    func popularNucleoPontaGrossa(context: NSManagedObjectContext) {
        popularNucleo(
            nomeRegional: "Ponta Grossa",
            lista: [
                ("João Alfredo Thomé", "Chefe"),
                ("Alexandre Vieira", nil),
                ("Francine Barganha Machado Tullio", nil),
                ("Henriette Gomes", nil),
                ("Douglas Wellington Gouvea Junior", nil),
                ("Jessica Eliane Vaz Pereira", nil)
            ],
            context: context
        )
    }

    // MARK: - UNIÃO DA VITÓRIA
    func popularNucleoUniaoDaVitoria(context: NSManagedObjectContext) {
        popularNucleo(
            nomeRegional: "Uniao da Vitoria",
            lista: [
                ("Nelson Ronaldo Pedroso", "Chefe"),
                ("Ana Caroline Kreckinski", nil),
                ("Vinícius Alexandre Tomio da Motta", nil)
            ],
            context: context
        )
    }

    // MARK: - LONDRINA
    func popularNucleoLondrina(context: NSManagedObjectContext) {
        popularNucleo(
            nomeRegional: "Londrina",
            lista: [
                ("Fábio Bali Oliveira", "Chefe"),
                ("Flávia Roberta Roque de Lima Reis", nil),
                ("Marcel S. Cichocki de Baravi Vasconcellos", nil),
                ("Marlo Eduardo Roncaglio", nil),
                ("Ana Letícia Craco", nil),
                ("Giovana Sticca de Souza", nil),
                ("Eduardo Grzeszeski de Carvalho", nil)
            ],
            context: context
        )
    }
    // MARK: - SANTO ANTÔNIO DA PLATINA
       func popularNucleoSantoAntonio(context: NSManagedObjectContext) {
           popularNucleo(
               nomeRegional: "Santo Antonio da Platina",
               lista: [
                   ("João Vítor de Oliveira Navarro", "Chefe"),
                   ("Jonas Ribeiro", nil),
                   ("Gabriel Barbosa Joanitis", nil),
                   ("Izabelle Leal de Godoi", nil),
                   ("João Afonso Silva Peixe Cavenaghi", nil)
               ],
               context: context
           )
       }

       // MARK: - CASCAVEL
       func popularNucleoCascavel(context: NSManagedObjectContext) {
           popularNucleo(
               nomeRegional: "Cascavel",
               lista: [
                   ("Ricardo Ceola", "Chefe"),
                   ("Leandro Sandalo Piana", nil),
                   ("Pedro Antonio Perin Ribas", nil),
                   ("Renan Calvo", nil),
                   ("Nicole Santos da Silva", nil),
                   ("Stefani Triper Gonçalves", nil),
                   ("Flávia Cristina de Azevedo Pinto Knupp", nil)
               ],
               context: context
           )
       }

       // MARK: - MARINGÁ
       func popularNucleoMaringa(context: NSManagedObjectContext) {
           popularNucleo(
               nomeRegional: "Maringa",
               lista: [
                   ("Gustavo Vidor Godoi", "Chefe"),
                   ("Enzo Bernardes Rizzo", nil),
                   ("Isabel Campos Barros", nil),
                   ("Marcos Antonio Franco", nil),
                   ("Rômulo Menck Romanichen", nil),
                   ("Suely Xavier Lisboa", nil),
                   ("Edilen Henrique Xavier", nil),
                   ("Glória Fort", nil),
                   ("Guilherme Henrique Montagnini", nil),
                   ("Tatiana de Farias Alves", nil)
               ],
               context: context
           )
       }

       // MARK: - PATO BRANCO
       func popularNucleoPatoBranco(context: NSManagedObjectContext) {
           popularNucleo(
               nomeRegional: "Pato Branco",
               lista: [
                   ("Joceandro Tonial", "Chefe"),
                   ("Érico Hiyoshi Iwata", nil),
                   ("Caroline Martins Lima", nil),
                   ("Agada Costa Rosaneli", nil),
                   ("Adriele Moretto", nil)
               ],
               context: context
           )
       }
    
    // MARK: - CAMPO MOURÃO
        func popularNucleoCampoMourao(context: NSManagedObjectContext) {
            popularNucleo(
                nomeRegional: "Campo Mourao",
                lista: [
                    ("Fernando Cavali Almeida", "Chefe"),
                    ("Juliano Tezolin", nil),
                    ("Lucas Felipe Garippo Peixoto", nil),
                    ("Rodrigo Gonçalves Ferreira da Silva", nil),
                    ("Aniele Carolline Arantes Silva", nil),
                    ("Victor Hugo Schroder", nil),
                    ("Edel Idilio Rocha", nil)
                ],
                context: context
            )
        }

        // MARK: - GUARAPUAVA
        func popularNucleoGuarapuava(context: NSManagedObjectContext) {
            popularNucleo(
                nomeRegional: "Guarapuava",
                lista: [
                    ("José Luiz Cieslack", "Chefe"),
                    ("Melissa Robertha Cuco de Almeida", nil),
                    ("Gabriel Menon de Lima", nil),
                    ("Ariel Rodrigues de Lima", nil),
                    ("Flavio Augusto Prado", nil),
                    ("Alison Diego Buava", nil),
                    ("Gabriela Haag Coelho", nil)
                ],
                context: context
            )
        }

        // MARK: - UMUARAMA
        func popularNucleoUmuarama(context: NSManagedObjectContext) {
            popularNucleo(
                nomeRegional: "Umuarama",
                lista: [
                    ("Vivianne Mendes Lowe", "Chefe"),
                    ("Fernando Nicolau Tolentino", nil),
                    ("Ana Luiza Oliveira Santos", nil),
                    ("Marcelo Junior Ferreira Almansa", nil)
                ],
                context: context
            )
        }
    // MARK: - Função Genérica Reutilizável
    private func popularNucleo(nomeRegional: String, lista: [(String, String?)], context: NSManagedObjectContext) {
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        request.predicate = NSPredicate(format: "regional == %@", nomeRegional)

        print("🔹 Populando Núcleo Regional de \(nomeRegional) para esta instalação (sempre cria novas instâncias)...")

        for (nome, funcao) in lista {
            let novo = Funcionario(context: context)
            novo.id = UUID() // sempre um novo UUID por instalação
            novo.nome = "\(nome)"
            // Note: We prefix the name with the per-install installID so we can filter locally without schema changes.
            novo.funcao = funcao
            novo.regional = nomeRegional
            novo.email = ""
            novo.celular = ""
            novo.ramal = ""
        }

        do {
            try context.save()
            print("✅ Núcleo Regional de \(nomeRegional) inserido com sucesso (novas instâncias por instalação).")
            fetchFuncionarios()
        } catch {
            print("❌ Erro ao salvar dados iniciais de \(nomeRegional): \(error)")
        }
    }
}
// MARK: - POPULAR REGIONALINFO5 (INFORMAÇÕES DAS REGIONAIS)
extension FuncionarioViewModel {

    func popularRegionaisInfo(context: NSManagedObjectContext) {

        _ = NSFetchRequest<NSFetchRequestResult>(entityName: "RegionalInfo5")

        print("🔹 Populando tabela RegionalInfo5 com endereço, chefe e ramal...")
        // NOVA ESTRUTURA COMPLETA
        let valores1: [(String, String, String, String)] = [
            (
                "Curitiba",
                "ENG. CIVIL CINTHIA APARECIDA DE LIMA",
                "41 3210-2938",
                """
                Rua Jacy Loureiro de Campos, nº 6, 2º andar,
                Praça Nossa Senhora de Santa Salete – Palácio das Araucárias,
                CEP 82590-300 – Curitiba-PR
                """
            ),
            (
                "Ponta Grossa",
                "ENG. CIVIL JOAO ALFREDO THOME",
                "42 99144-7400",
                """
                Rua José do Patrocínio, 238B – CEP 84040-200,
                Ponta Grossa-PR
                """
            ),
            (
                "União da Vitória",
                "ADV. NELSON RONALDO PEDROSO",
                "42 99955-8564",
                """
                Avenida Bento Munhoz da Rocha Neto 1251,
                Bairro São Bernardo do Campo – CEP 84600-348,
                União da Vitória-PR
                """
            ),
            (
                "Londrina",
                "ENG. CIVIL FABIO BAHL OLIVEIRA",
                "(41) 98846-2339",
                """
                Rua Cambará, 207 – CEP 86010-530,
                Londrina-PR
                """
            ),
            (
                "Santo Antônio da Platina",
                "ENG. CIVIL JOÃO VITOR DE OLIVEIRA NABARRO",
                "41 98846-2696",
                """
                Rua Marechal Deodoro da Fonseca, 185 – Centro,
                CEP 86430-000 – Santo Antônio da Platina-PR
                """
            ),
            (
                "Cascavel",
                "ARQUITETO RICARDO CEOLA",
                "45 3223-2081",
                """
                Rua Antonina, 2406 – Centro – CEP 85812-040,
                Cascavel-PR
                """
            ),
            (
                "Maringá",
                "ENG. CIVIL GUSTAVO VIDOR GODOI",
                "44 99948-5647",
                """
                Avenida Humaitá 268 – Zona 4 – CEP 87014-200,
                Maringá-PR
                """
            ),
            (
                "Pato Branco",
                "ENG. CIVIL JOCEANDRO TONIAL",
                "46 3220-7220",
                """
                Rua Sete de Setembro, 363 – CEP 85506-040,
                Pato Branco-PR
                """
            ),
            (
                "Campo Mourão",
                "ENG. CIVIL FERNANDO CAVALI ALMEIDA",
                "44 99846-7698",
                """
                Avenida Capitão Índio Bandeira, 920, 2º andar,
                Prédio da PGE (anexo à Agência de Rendas) – Centro,
                CEP 87300-005 – Campo Mourão-PR
                """
            ),
            (
                "Guarapuava",
                "ENG. CIVIL JOSE LUIZ CIESLACK",
                "42 3621-7316",
                """
                Rua Cônego Braga, 25 – Centro – CEP 85010-050,
                Guarapuava-PR
                """
            ),
            (
                "Umuarama",
                "ENG. CIVIL VIVIANNE MENDES LOWE",
                "44 99936-9211",
                """
                Rua Walter Kraiser, 3055 – CEP 87503-660,
                Umuarama-PR
                """
            )
        ]

        // INSERÇÃO NO CORE DATA
        for (nome, chefe, ramal, endereco) in valores1 {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "RegionalInfo5", into: context)
            obj.setValue(nome, forKey: "nome")
            obj.setValue(chefe, forKey: "chefe")
            obj.setValue(ramal, forKey: "ramal")
            obj.setValue(endereco, forKey: "endereco")
        }

        do {
            try context.save()
            print("✅ RegionalInfo5 populado com sucesso com endereço completo!")
        } catch {
            print("❌ Erro ao salvar RegionalInfo5: \(error.localizedDescription)")
        }
    }

}

