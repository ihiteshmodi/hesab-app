import LocalAuthentication

/// Face ID, Touch ID or the device passcode. The UI tests answer for the phone: `-ui-testing` always succeeds, `-ui-auth-fail` always fails.
enum PrivacyGate {
    private static var arguments: [String] { CommandLine.arguments }
    static var isUITesting: Bool { arguments.contains("-ui-testing") }

    /// App Lock needs Face ID or Touch ID, not just a passcode.
    static var biometricsAvailable: Bool {
        if isUITesting { return true }
        var failure: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &failure)
    }

    static func authenticate(reason: String) async -> Bool {
        if isUITesting { return !arguments.contains("-ui-auth-fail") }
        let context = LAContext()
        var failure: NSError?
        // With no biometrics and no passcode there is nothing to ask, so showing is allowed.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &failure) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
