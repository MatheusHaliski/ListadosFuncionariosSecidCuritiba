#if canImport(UIKit)
import UIKit
import SwiftUI

final class EmployeesTableViewController: UITableViewController {
    private var employees: [Funcionario]
    private let contactService: ContactService
    private let openURLHandler: (URL) -> Void
    private let onEdit: (Funcionario) -> Void
    private let onDelete: (Funcionario) -> Void

    init(
        employees: [Funcionario],
        contactService: ContactService,
        openURL: @escaping (URL) -> Void,
        onEdit: @escaping (Funcionario) -> Void,
        onDelete: @escaping (Funcionario) -> Void
    ) {
        self.employees = employees
        self.contactService = contactService
        self.openURLHandler = openURL
        self.onEdit = onEdit
        self.onDelete = onDelete
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    func update(employees: [Funcionario]) {
        self.employees = employees
        tableView.reloadData()
    }

    // MARK: - Table view data source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        employees.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let f = employees[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = f.nome ?? "—"
        content.secondaryText = f.funcao
        cell.contentConfiguration = content

        // Trailing calling options as accessoryView (WhatsApp, Call, Email)
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12

        func makeButton(image: UIImage?, systemName: String?, action: @escaping () -> Void) -> UIButton {
            let button = UIButton(type: .system)

            // Container circle with border and shadow
            let circle = UIView()
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.backgroundColor = .systemBackground
            circle.layer.cornerRadius = 22
            circle.layer.borderColor = UIColor.black.withAlphaComponent(0.4).cgColor
            circle.layer.borderWidth = 1
            circle.layer.shadowColor = UIColor.black.cgColor
            circle.layer.shadowOpacity = 0.25
            circle.layer.shadowRadius = 2
            circle.layer.shadowOffset = CGSize(width: 0, height: 1)

            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit

            if let image = image {
                imageView.image = image.withRenderingMode(.alwaysOriginal)
            } else if let systemName = systemName {
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
                imageView.image = UIImage(systemName: systemName, withConfiguration: config)
                imageView.tintColor = .systemBlue
            }

            circle.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 22),
                imageView.heightAnchor.constraint(equalToConstant: 22),
                imageView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
            ])

            button.addSubview(circle)
            NSLayoutConstraint.activate([
                circle.widthAnchor.constraint(equalToConstant: 44),
                circle.heightAnchor.constraint(equalToConstant: 44),
                circle.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                circle.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                circle.topAnchor.constraint(equalTo: button.topAnchor),
                circle.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])

            button.contentEdgeInsets = .zero
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            return button
        }

        if let phone = f.celular, !phone.isEmpty {
            let whatsappImage = UIImage(named: "whatsapp")
            let whatsapp = makeButton(image: whatsappImage, systemName: whatsappImage == nil ? "message.circle.fill" : nil) { [weak self] in
                guard let self = self else { return }
                _ = self.contactService.contact(
                    .whatsapp,
                    for: EmployeeContact(name: f.nome, email: f.email, phone: phone),
                    openURL: { url in self.openURLHandler(url); return true }
                )
            }
            whatsapp.accessibilityLabel = NSLocalizedString("contact.whatsapp", comment: "WhatsApp")
            stack.addArrangedSubview(whatsapp)

            let call = makeButton(image: nil, systemName: "phone.circle.fill") { [weak self] in
                guard let self = self else { return }
                _ = self.contactService.contact(
                    .call,
                    for: EmployeeContact(name: f.nome, email: f.email, phone: phone),
                    openURL: { url in self.openURLHandler(url); return true }
                )
            }
            call.accessibilityLabel = NSLocalizedString("contact.call", comment: "Call")
            stack.addArrangedSubview(call)
        }

        if let email = f.email, !email.isEmpty {
            let mail = makeButton(image: nil, systemName: "envelope.circle.fill") { [weak self] in
                guard let self = self else { return }
                _ = self.contactService.contact(
                    .email,
                    for: EmployeeContact(name: f.nome, email: email, phone: f.celular),
                    openURL: { url in self.openURLHandler(url); return true }
                )
            }
            mail.accessibilityLabel = NSLocalizedString("contact.email", comment: "Email")
            stack.addArrangedSubview(mail)
        }

        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        let size = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        container.frame = CGRect(origin: .zero, size: CGSize(width: max(88, size.width), height: 36))
        cell.accessoryView = container

        cell.selectionStyle = .default
        cell.accessoryType = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let f = employees[indexPath.row]
        onEdit(f)
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: NSLocalizedString("delete", comment: "")) { [weak self] _, _, completion in
            guard let self = self else { return }
            let f = self.employees[indexPath.row]
            self.onDelete(f)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}
#endif

struct EmployeesTableWrapper: UIViewControllerRepresentable {
    var employees: [Funcionario]
    let contactService: ContactService
    var onEdit: (Funcionario) -> Void
    var onDelete: (Funcionario) -> Void

    @Environment(\.openURL) private var openURL

    func makeUIViewController(context: Context) -> EmployeesTableViewController {
        EmployeesTableViewController(
            employees: employees,
            contactService: contactService,
            openURL: { url in openURL(url) },
            onEdit: onEdit,
            onDelete: onDelete
        )
    }

    func updateUIViewController(_ vc: EmployeesTableViewController, context: Context) {
        vc.update(employees: employees)
    }
}
