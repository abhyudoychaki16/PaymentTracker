import SwiftUI
import SwiftData

struct PaymentFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var categoryStore: CategoryStore

    @State private var amountText = ""
    @State private var note = ""
    @State private var category = "Food"
    @State private var paymentMethod = "Unknown"
    @State private var isInflow = false
    @State private var isBill = false
    @State private var errorMessage: String?

    private let viewModel = TransactionViewModel()

    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    Picker("Type", selection: $isInflow) {
                        Text("Expense").tag(false)
                        Text("Income").tag(true)
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Amount")
                    }

                    TextField("Description", text: $note)
                        .textInputAutocapitalization(.sentences)

                    Picker("Category", selection: $category) {
                        ForEach(categoryStore.categories, id: \.self) { Text($0) }
                    }

                    Picker("Payment method", selection: $paymentMethod) {
                        ForEach(CategoryStore.methods, id: \.self) { Text($0) }
                    }

                    if !isInflow {
                        Toggle("Credit card bill payment", isOn: $isBill)
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled((parsedAmount ?? 0) <= 0 || note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else {
            errorMessage = "Enter a valid amount."
            return
        }
        do {
            try viewModel.addPayment(
                amount: amount,
                note: note,
                category: category,
                paymentMethod: paymentMethod,
                isInflow: isInflow,
                isFlaggedAsBill: isBill,
                to: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
