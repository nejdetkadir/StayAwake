import Testing

@testable import StayAwake

struct PermissionSetupTests {
    @Test func scriptInstallsRuleForUser() throws {
        let script = try #require(PermissionSetup.installScript(user: "jane.doe"))
        #expect(script.contains("'jane.doe ALL=(root) NOPASSWD: /usr/bin/pmset'"))
        #expect(script.contains("/usr/sbin/visudo -cf"))
        #expect(script.contains("-m 0440 -o root -g wheel"))
        #expect(script.contains(PermissionSetup.sudoersPath))
    }

    @Test(arguments: ["", "jane doe", "x'; rm -rf /", "$(id)", "jane\nALL", "ali̇"])
    func rejectsUnsafeUserNames(_ user: String) {
        #expect(PermissionSetup.installScript(user: user) == nil)
    }

    @Test func escapesAppleScriptLiterals() {
        #expect(PermissionSetup.appleScriptLiteral(#"echo "a\b""#) == #""echo \"a\\b\"""#)
    }
}
