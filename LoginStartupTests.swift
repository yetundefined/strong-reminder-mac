import Foundation

private final class FakeLoginService: LoginService {
    var status: LoginServiceStatus = .notRegistered
    var registerCalls = 0
    var unregisterCalls = 0

    func register() throws {
        registerCalls += 1
        status = .enabled
    }

    func unregister() throws {
        unregisterCalls += 1
        status = .notRegistered
    }
}

@main
struct LoginStartupTests {
    static func main() throws {
        let service = FakeLoginService()
        let settings = LoginStartupSettings(service: service)

        let firstEnable = try settings.setEnabled(true)
        precondition(firstEnable == .enabled)
        precondition(service.registerCalls == 1, "启用时应该注册登录项")
        let secondEnable = try settings.setEnabled(true)
        precondition(secondEnable == .enabled)
        precondition(service.registerCalls == 1, "重复启用不应再次注册")

        let firstDisable = try settings.setEnabled(false)
        precondition(firstDisable == .notRegistered)
        precondition(service.unregisterCalls == 1, "关闭时应该注销登录项")
        let secondDisable = try settings.setEnabled(false)
        precondition(secondDisable == .notRegistered)
        precondition(service.unregisterCalls == 1, "重复关闭不应再次注销")

        service.status = .requiresApproval
        let pendingApproval = try settings.setEnabled(true)
        precondition(pendingApproval == .requiresApproval)
        precondition(service.registerCalls == 1, "等待系统批准时不应再次注册")

        print("LoginStartupTests: 5 passed")
    }
}
