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
    let objectWillChange = ObservableObjectPublisher()
    
    @Published var funcionarios: [Funcionario] = []

    private var context: NSManagedObjectContext

    init() {
        self.objectWillChange.send() // optional early signal; harmless
        self.context = PersistenceController.shared.container.viewContext
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

    func fetchFuncionarios() {
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
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
    /// Other fields (funcao, ramal, celular, email) are cleared.
    func resetToDefaultMode() {
        let request: NSFetchRequest<Funcionario> = Funcionario.fetchRequest()
        do {
            let all = try context.fetch(request)
            for funcionario in all {
                // Preserve nome and regional; clear the rest
                funcionario.funcao = ""
                funcionario.ramal = ""
                funcionario.celular = ""
                funcionario.email = ""
                funcionario.imagemURL = nil
                funcionario.imagem = nil
            }
            try context.save()
            fetchFuncionarios()
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
    let collection = db.collection("funcionarios")

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

        if let count = try? context.count(for: request), count == 0 {
            print("🔹 Populando Núcleo Regional de \(nomeRegional)...")

            for (nome, funcao) in lista {
                let novo = Funcionario(context: context)
                novo.id = UUID()
                novo.nome = nome
                novo.funcao = funcao
                novo.regional = nomeRegional
                novo.email = ""
                novo.celular = ""
                novo.ramal = ""
            }

            do {
                try context.save()
                print("✅ Núcleo Regional de \(nomeRegional) inserido com sucesso.")
                fetchFuncionarios()
            } catch {
                print("❌ Erro ao salvar dados iniciais de \(nomeRegional): \(error)")
            }
        }
    }
}

