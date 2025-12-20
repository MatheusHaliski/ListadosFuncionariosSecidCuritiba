// ContactService.swift
// Encapsulates safe URL building and launching for employee contact methods.

import Foundation
import SwiftUI

public struct EmployeeContact {
    public let name: String?
    public let email: String?
    public let phone: String?

    public init(name: String?, email: String?, phone: String?) {
        self.name = name
        self.email = email
        self.phone = phone
    }
}

public enum ContactMethod {
    case call
    case email
    case whatsapp
}

public protocol ContactService {
    /// Build and open a URL for the given contact method. The caller provides the `openURL` closure (e.g. from `@Environment(\.openURL)`).
    func contact(_ method: ContactMethod, for employee: EmployeeContact, openURL: (URL) -> Bool)
}

extension String {
    fileprivate var digitsOnly: String { self.filter { $0.isNumber } }
}

public final class DefaultContactService: ContactService {
    public static let shared = DefaultContactService()
    public init() {}

    public func contact(_ method: ContactMethod, for employee: EmployeeContact, openURL: (URL) -> Bool) {
        switch method {
        case .call:
            guard let phone = employee.phone?.digitsOnly, !phone.isEmpty else { return }
            if let tel = makeTelURL(from: phone), openURL(tel) { return }
            // Fallbacks for environments that don't handle tel:
            if let facetimeAudio = makeFaceTimeAudioURL(from: phone), openURL(facetimeAudio) { return }
            if let facetime = makeFaceTimeURL(from: phone), openURL(facetime) { return }
            return
        case .email:
            guard let email = employee.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty, isValidEmail(email) else { return }
            let subject = "Hello \(employee.name ?? "")"
            if let mailto = makeMailtoURL(email: email, subject: subject), openURL(mailto) { return }
            // Web fallback (e.g., on macOS or Simulator)
            if let web = makeGmailComposeURL(email: email, subject: subject) { _ = openURL(web) }
            return
        case .whatsapp:
            let text = "Hello \(employee.name ?? "")"
            let digits = employee.phone?.digitsOnly
            guard let url = makeWhatsAppURL(phoneDigits: digits, text: text) else { return }
            _ = openURL(url)
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    private func makeTelURL(from digits: String) -> URL? {
        URL(string: "tel:\(digits)")
    }

    private func makeMailtoURL(email: String, subject: String) -> URL? {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(email)?subject=\(encodedSubject)")
    }

    private func makeWhatsAppURL(phoneDigits: String?, text: String) -> URL? {
        let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let digits = phoneDigits, !digits.isEmpty {
            return URL(string: "https://wa.me/\(digits)?text=\(encodedText)")
        } else {
            return URL(string: "https://wa.me/?text=\(encodedText)")
        }
    }

    private func makeFaceTimeAudioURL(from digits: String) -> URL? {
        URL(string: "facetime-audio://\(digits)")
    }

    private func makeFaceTimeURL(from digits: String) -> URL? {
        URL(string: "facetime://\(digits)")
    }

    private func makeGmailComposeURL(email: String, subject: String) -> URL? {
        let encodedTo = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://mail.google.com/mail/?view=cm&to=\(encodedTo)&su=\(encodedSubject)")
    }
}

public protocol ContactServiceProtocol {
    func call(url: URL, openURL: OpenURLAction)
    func mail(url: URL, openURL: OpenURLAction)
}

public struct ContactServiceKey: EnvironmentKey {
    public static let defaultValue: ContactServiceProtocol = DefaultContactService()
}

public extension EnvironmentValues {
    public var contactService: ContactServiceProtocol {
        get { self[ContactServiceKey.self] }
        set { self[ContactServiceKey.self] = newValue }
    }
}

extension DefaultContactService: ContactServiceProtocol {
    public func call(url: URL, openURL: OpenURLAction) {
        _ = openURL(url)
    }

    public func mail(url: URL, openURL: OpenURLAction) {
        _ = openURL(url)
    }
}
