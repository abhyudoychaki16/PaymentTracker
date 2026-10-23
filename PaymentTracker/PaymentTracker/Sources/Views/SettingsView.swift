import SwiftUI

struct SettingsView: View {
    @AppStorage("dropsplit.displayName") private var displayName = ""
    @AppStorage("dropsplit.upiID") private var upiID = ""
    @AppStorage("payment.currencyCode") private var currencyCode = PaymentPreferences.defaultCurrencyCode
    @AppStorage("dashboard.defaultPeriod") private var defaultPeriod = "today"
    @AppStorage("dropsplit.notificationsEnabled") private var splitNotificationsEnabled = true

    var body: some View {
        Form {
            Section {
                TextField("Your name", text: $displayName)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                TextField("UPI ID", text: $upiID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                if !upiID.isEmpty && !DropSplitService.isValidUPI(upiID) {
                    Label("Enter a valid UPI ID, such as name@bank", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("DropSplit profile")
            } footer: {
                Text("Your name and UPI ID are included in DropSplit requests you share. Check them before sending.")
            }

            Section("Dashboard and display") {
                Picker("Default date range", selection: $defaultPeriod) {
                    Text("Today").tag("today")
                    Text("7 days").tag("sevenDays")
                    Text("30 days").tag("thirtyDays")
                }
                Picker("Currency", selection: $currencyCode) {
                    Text("Indian rupee (INR)").tag("INR")
                    Text("US dollar (USD)").tag("USD")
                    Text("Euro (EUR)").tag("EUR")
                    Text("Pound sterling (GBP)").tag("GBP")
                    if !["INR", "USD", "EUR", "GBP"].contains(PaymentPreferences.defaultCurrencyCode) {
                        Text("Device default (\(PaymentPreferences.defaultCurrencyCode))")
                            .tag(PaymentPreferences.defaultCurrencyCode)
                    }
                }
                Text("Currency changes the way amounts are displayed. It does not convert transaction values; UPI payments remain in INR.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("DropSplit notifications", isOn: $splitNotificationsEnabled)
            } footer: {
                Text("Notifications are requested on this phone when a DropSplit request is opened. iOS notification settings still control delivery.")
            }

            Section {
                LabeledContent("App lock", value: "Face ID or passcode")
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("Privacy policy", systemImage: "hand.raised")
                }
                NavigationLink {
                    MessageImportHelpView()
                } label: {
                    Label("Message import setup", systemImage: "message.badge")
                }
                NavigationLink {
                    CategoryManagementView()
                } label: {
                    Label("Manage categories", systemImage: "tag")
                }
            } header: {
                Text("Privacy and import")
            } footer: {
                Text("Payment Tracker requires device authentication to protect your financial data. Message imports are controlled by your Shortcuts automation.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
