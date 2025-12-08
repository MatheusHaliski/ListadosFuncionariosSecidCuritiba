import SwiftUI
import Combine

// App-wide navigation state for programmatic root navigation between screens.
class AppNavigationState: ObservableObject {
    enum Screen {
        case main  // PaginaGrandeView
        case detail(Funcionario)  // Details for an employee
        // Add more cases if needed
    }
    @Published var screen: Screen = .main
}

