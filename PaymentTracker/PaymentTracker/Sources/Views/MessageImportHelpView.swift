import SwiftUI

struct MessageImportHelpView: View {
    var body: some View {
        List {
            Section {
                Text("A Message automation can pass matching bank texts to Payment Tracker. Detected transactions are saved automatically as Uncategorized; edit the category later in the app.")
                    .foregroundStyle(.secondary)
            }

            Section("Set up the automation") {
                instruction(1, "Open Shortcuts → Automation → New Automation → Message.")
                instruction(2, "Choose your bank as the sender when possible. Otherwise use a keyword such as “Spent”, “Sent”, or “credited”.")
                instruction(3, "Choose Run Immediately (or turn off Ask Before Running), then add the Import Payment Message action from Payment Tracker.")
                instruction(4, "Pass Shortcut Input into Message text. If you use several keyword automations, keep one import action in each; duplicate copies of the same SMS are ignored.")
                instruction(5, "In the shortcut’s Info → Privacy settings, enable Allow Running When Locked.")
            }

            Section("What gets saved") {
                Text("Payment Tracker only imports messages that include a completed transaction event, a bank or payment-method marker, and a readable amount. It saves locally with the import time. Incoming credits remain Uncategorized.")
                Text("If an imported expense is a credit-card bill payment, open it and turn on Credit card bill payment. Marked bill payments are excluded from spending totals and charts.")
                Text("iOS controls when Message automations run. If an import is missed, check that the automation is enabled, set to run immediately, and allowed to run while locked. Focus modes may silence notifications, but the app cannot force a Shortcuts automation to run.")
                    .foregroundStyle(.secondary)
                Text("The message is parsed on your device; Payment Tracker does not send it to a server.")
                    .foregroundStyle(.secondary)
            }

        }
        .navigationTitle("Import Messages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue, in: Circle())
            Text(text)
        }
        .padding(.vertical, 3)
    }
}
