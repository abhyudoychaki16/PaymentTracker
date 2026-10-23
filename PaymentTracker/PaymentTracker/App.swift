import SwiftUI
import SwiftData
import LocalAuthentication
import UserNotifications
import UIKit

@main
struct PaymentTrackerApp: App {
    @StateObject private var categoryStore = CategoryStore()
    @UIApplicationDelegateAdaptor(PaymentTrackerNotificationDelegate.self) private var notificationDelegate

    init() {
        PaymentPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            AppLockGate()
                .modelContainer(PersistenceController.shared.modelContainer)
                .environmentObject(categoryStore)
        }
    }
}

private final class PaymentTrackerNotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

private struct AppLockGate: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var isUnlocked = false
    @State private var errorMessage: String?
    @State private var authenticationInProgress = false
    @State private var authenticateOnNextActivation = false
    @State private var isSceneInactive = false
    @State private var didRequestInitialAuthentication = false
    @State private var biometricFailureCount = 0
    @State private var shouldUsePasscode = false
    @State private var incomingDropSplitURL: URL?

    var body: some View {
        Group {
            if isUnlocked {
                ContentView()
            } else {
                let isDarkMode = colorScheme == .dark
                let foreground = isDarkMode ? Color.white : Color.black
                ZStack {
                    (isDarkMode ? Color.black : Color.white)
                        .ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(foreground)
                            .frame(width: 76, height: 76)
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(foreground.opacity(0.16), lineWidth: 1))
                        Text("Payment Tracker")
                            .font(.largeTitle.bold())
                            .foregroundStyle(foreground)
                        Text("Unlock to view your transactions")
                            .foregroundStyle(foreground.opacity(0.62))
                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(foreground.opacity(0.8))
                        }
                        Button(action: shouldUsePasscode ? authenticateWithPasscodeFallback : authenticate) {
                            Label(shouldUsePasscode ? "Continue with iPhone Passcode" : (biometricFailureCount == 0 ? "Unlock with Face ID" : "Try Face ID Again"),
                                  systemImage: shouldUsePasscode ? "number" : "faceid")
                                .font(.headline)
                                .foregroundStyle(isDarkMode ? .black : .white)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 14)
                                .background(foreground, in: Capsule())
                        }
                        .padding(.top, 8)
                    }
                    .padding(32)
                }
            }
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "dropsplit" else { return }
            if isUnlocked {
                receiveDropSplit(url)
            } else {
                incomingDropSplitURL = url
            }
        }
        .onChange(of: isUnlocked) { _, unlocked in
            guard unlocked, let url = incomingDropSplitURL else { return }
            incomingDropSplitURL = nil
            receiveDropSplit(url)
        }
        .overlay {
            if isUnlocked && isSceneInactive {
                Color.black.ignoresSafeArea()
            }
        }
        .task {
            await Task.yield()
            guard !didRequestInitialAuthentication else { return }
            didRequestInitialAuthentication = true
            if scenePhase == .active {
                authenticate()
            } else {
                authenticateOnNextActivation = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                // Hide transaction details in the app switcher without making brief
                // interruptions such as Control Center require another Face ID scan.
                isSceneInactive = true
            case .background:
                isSceneInactive = true
                if isUnlocked {
                    isUnlocked = false
                    authenticateOnNextActivation = true
                }
            case .active:
                isSceneInactive = false
                if authenticateOnNextActivation && !authenticationInProgress {
                    authenticateOnNextActivation = false
                    authenticate()
                }
            @unknown default:
                break
            }
        }
    }

    private func receiveDropSplit(_ url: URL) {
        do {
            let request = try DropSplitService.request(from: url)
            guard try DropSplitService.receive(request, into: modelContext) else { return }
            Task { await DropSplitNotifications.notifyReceived(request) }
        } catch {
            NSLog("Payment Tracker could not import DropSplit: %@", error.localizedDescription)
        }
    }

    private func authenticate() {
        guard !authenticationInProgress, !isUnlocked, scenePhase == .active else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &policyError) else {
            shouldUsePasscode = true
            errorMessage = policyError?.localizedDescription ?? "Set a device passcode to protect PaymentTracker."
            return
        }
        authenticationInProgress = true
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Payment Tracker") { success, error in
            DispatchQueue.main.async {
                authenticationInProgress = false
                let canUnlock = success && scenePhase == .active
                isUnlocked = canUnlock
                authenticateOnNextActivation = !canUnlock && scenePhase != .active
                if canUnlock {
                    biometricFailureCount = 0
                    shouldUsePasscode = false
                    errorMessage = nil
                    return
                }

                guard let authError = error as? LAError else {
                    errorMessage = error?.localizedDescription
                    return
                }
                switch authError.code {
                case .userCancel, .appCancel, .systemCancel:
                    // Cancellation and app switching shouldn't consume a Face ID attempt.
                    errorMessage = nil
                case .userFallback, .biometryLockout, .biometryNotAvailable, .biometryNotEnrolled:
                    shouldUsePasscode = true
                    errorMessage = "Use your iPhone passcode to unlock Payment Tracker."
                default:
                    biometricFailureCount += 1
                    shouldUsePasscode = biometricFailureCount >= 2
                    errorMessage = shouldUsePasscode
                        ? "Face ID didn’t work twice. Continue with your iPhone passcode."
                        : "Face ID didn’t match. Try once more."
                }
            }
        }
    }

    private func authenticateWithPasscodeFallback() {
        guard !authenticationInProgress, !isUnlocked, scenePhase == .active else { return }
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"
        var policyError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &policyError) else {
            errorMessage = policyError?.localizedDescription ?? "Set a device passcode to protect Payment Tracker."
            return
        }
        authenticationInProgress = true
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Payment Tracker") { success, error in
            DispatchQueue.main.async {
                authenticationInProgress = false
                let canUnlock = success && scenePhase == .active
                isUnlocked = canUnlock
                authenticateOnNextActivation = !canUnlock && scenePhase != .active
                if canUnlock {
                    biometricFailureCount = 0
                    shouldUsePasscode = false
                    errorMessage = nil
                } else if let authError = error as? LAError, authError.code == .userCancel || authError.code == .appCancel || authError.code == .systemCancel {
                    errorMessage = nil
                } else {
                    errorMessage = error?.localizedDescription
                }
            }
        }
    }
}
