import SwiftUI
import CoreData

struct BuscarFuncionarioView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Funcionario.nome, ascending: true)],
        animation: .default
    ) private var funcionarios: FetchedResults<Funcionario>
    
    @State private var searchText = ""
    
    var filteredFuncionarios: [Funcionario] {
        guard !searchText.isEmpty else { return Array(funcionarios) }
        return funcionarios.filter { funcionario in
            (funcionario.nome?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (funcionario.funcao?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (funcionario.regional?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredFuncionarios, id: \.objectID) { funcionario in
                    NavigationLink(destination: FuncionarioDetailView(funcionario: funcionario)) {
                        FuncionarioRowViewV2(funcionario: funcionario)
                    }
                }
                if filteredFuncionarios.isEmpty {
                    Text("Nenhum funcionário encontrado")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Buscar Funcionário")
            .searchable(text: $searchText, prompt: "Buscar por nome, função ou regional")
        }
    }
}

#Preview {
    BuscarFuncionarioView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
