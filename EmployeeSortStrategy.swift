import Foundation

protocol EmployeeSortStrategy {
    func sort(_ employees: [Funcionario]) -> [Funcionario]
}

struct SortByName: EmployeeSortStrategy {
    func sort(_ employees: [Funcionario]) -> [Funcionario] {
        employees.sorted { ($0.nome ?? "").localizedCaseInsensitiveCompare($1.nome ?? "") == .orderedAscending }
    }
}

struct SortByFunction: EmployeeSortStrategy {
    func sort(_ employees: [Funcionario]) -> [Funcionario] {
        employees.sorted { ($0.funcao ?? "").localizedCaseInsensitiveCompare($1.funcao ?? "") == .orderedAscending }
    }
}

struct EmployeeSorter {
    var strategy: EmployeeSortStrategy
    func sort(_ employees: [Funcionario]) -> [Funcionario] { strategy.sort(employees) }
}

struct SortByRegional: EmployeeSortStrategy {
    func sort(_ list: [Funcionario]) -> [Funcionario] {
        list.sorted { (lhs, rhs) in
            (lhs.regional ?? "").localizedCaseInsensitiveCompare(rhs.regional ?? "") == .orderedAscending
        }
    }
}
