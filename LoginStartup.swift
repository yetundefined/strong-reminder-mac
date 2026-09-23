import Foundation
import ServiceManagement

enum LoginServiceStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
}

protocol LoginService {
    var status: LoginServiceStatus { get }
    func register() throws
    func unregister() throws
}

struct LoginStartupSettings {
    let service: any LoginService

    var status: LoginServiceStatus { service.status }

    @discardableResult
    func setEnabled(_ enabled: Bool) throws -> LoginServiceStatus {
        let current = service.status
        if enabled && (current == .notRegistered || current == .notFound) {
            try service.register()
        } else if !enabled && (current == .enabled || current == .requiresApproval) {
            try service.unregister()
        }
        return service.status
    }
}

struct MainAppLoginService: LoginService {
    private let service = SMAppService.mainApp

    var status: LoginServiceStatus {
        switch service.status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }

    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
}
