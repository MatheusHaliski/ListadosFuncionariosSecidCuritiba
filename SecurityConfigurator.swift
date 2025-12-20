import Foundation

enum SecurityConfigurator {
    static func applyFileProtection() {
        let fm = FileManager.default
        let urls: [URL]
        do {
            let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let contents = (try? fm.contentsOfDirectory(at: appSupport, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
            urls = contents.filter { $0.pathExtension == "sqlite" || $0.lastPathComponent.contains(".sqlite") }
        } catch {
            return
        }
        for url in urls {
            do {
                try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            } catch {
            }
        }
    }
}
