import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Payment Tracker Privacy Policy")
                    .font(.largeTitle.bold())
                Text("Last updated October 24, 2026")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                policySection("Data on your device", "Payment Tracker stores transaction details, categories, payment methods, and split records locally on this iPhone. When you import a bank alert through a Shortcuts automation that you configured, the app parses it on device and stores the parsed transaction description plus a one-way fingerprint to prevent duplicate imports. It does not access the Messages inbox or store the full original message body.")

                policySection("DropSplit sharing", "A DropSplit request includes the sender name and UPI ID, recipient name, transaction description, category, payment method, amounts, and request date. The iOS share sheet sends it to the destination you choose. The recipient stores a separate copy; later payment status changes do not sync between phones.")

                policySection("Services and permissions", "The current app has no account service, app server, cloud synchronization, advertising SDK, or analytics SDK. Face ID and passcode checks use Apple's LocalAuthentication; Payment Tracker receives only the result and does not access biometric data. Local notifications are created on this device when enabled and permitted by iOS. Device backups are governed by your iOS backup settings.")

                policySection("Payments", "Payment Tracker does not connect to your bank or process payments. A UPI handoff opens a compatible payment app; you must review the payee and authorize any payment there. UPI payment requests use INR.")

                policySection("Retention and contact", "Records remain on this device until deleted using available app controls or the app and its local data are removed. A recipient controls their own DropSplit copy. For privacy questions or requests, email abhyudoychaki@gmail.com. The published policy URL still needs to be added to App Store Connect before release.")
            }
            .padding(20)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(body).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
