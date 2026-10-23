import SwiftUI
import SwiftData
import UIKit

struct SplitPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let payment: Payment

    @AppStorage("dropsplit.displayName") private var ownerName = ""
    @AppStorage("dropsplit.upiID") private var ownerUPI = ""
    @State private var names: [String]
    @State private var nameInput = ""
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var pendingRequest: DropSplitRequest?
    @State private var showingShareSheet = false

    init(payment: Payment) {
        self.payment = payment
        _names = State(initialValue: (payment.splits ?? []).map(\.personName))
    }

    private var share: Double {
        guard !names.isEmpty else { return payment.amount }
        return (payment.amount / Double(names.count + 1) * 100).rounded() / 100
    }
    private var currencyCode: String { PaymentPreferences.currencyCode }

    var body: some View {
        Form {
            Section {
                LabeledContent("Transaction", value: payment.note)
                LabeledContent("Total", value: payment.amount, format: .currency(code: currencyCode))
                LabeledContent("People", value: "You and \(names.count) others")
                LabeledContent("Each person pays", value: share, format: .currency(code: currencyCode))
            } header: {
                Text("Split details")
            } footer: {
                Text("DropSplit sends each person a private AirDrop request. Your share stays with you. Your name and UPI ID are managed in Settings.")
            }

            Section("Split with") {
                HStack {
                    TextField("Person’s name", text: $nameInput)
                        .textInputAutocapitalization(.words)
                        .onSubmit(addPerson)
                    Button("Add", action: addPerson)
                        .disabled(nameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                ForEach(names, id: \.self) { name in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name).font(.subheadline.weight(.semibold))
                            Text("Owes you \(share.formatted(.currency(code: currencyCode)))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            shareRequest(with: name)
                        } label: {
                            Label("AirDrop", systemImage: "airdrop")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent).tint(.teal)
                    }
                }
                .onDelete { names.remove(atOffsets: $0) }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(.red) }
            }

            Section {
                Button("Save split") { save(dismissAfterSave: true) }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .disabled(names.isEmpty)
            } footer: {
                Text("DropSplit balances live on each person’s phone. They can be settled in the app or with an exact UPI payment.")
            }
        }
        .navigationTitle("DropSplit")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet, onDismiss: { shareURL = nil }) {
            if let shareURL {
                DropSplitActivityView(url: shareURL) { completed in
                    guard let request = pendingRequest else { return }
                    pendingRequest = nil
                    if completed { recordSentRequest(request) }
                }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func addPerson() {
        let name = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard !names.contains(where: { $0.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            errorMessage = "That person is already in this split."
            return
        }
        names.append(name)
        nameInput = ""
        errorMessage = nil
    }

    private func shareRequest(with recipientName: String) {
        let payerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let payerUPI = ownerUPI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payerName.isEmpty else {
            errorMessage = "Add your name in Payment Tracker Settings before sending a DropSplit request."
            return
        }
        guard DropSplitService.isValidUPI(payerUPI) else {
            errorMessage = "Add a valid UPI ID in Payment Tracker Settings so they can pay you."
            return
        }

        let request = DropSplitRequest(
            id: UUID().uuidString,
            transactionNote: payment.note,
            category: payment.category,
            paymentMethod: payment.paymentMethod,
            transactionAmount: payment.amount,
            amountOwed: share,
            payerName: payerName,
            payerUPI: payerUPI,
            recipientName: recipientName,
            createdAt: .now
        )

        do {
            shareURL = try DropSplitService.makeShareURL(for: request)
            pendingRequest = request
            showingShareSheet = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recordSentRequest(_ request: DropSplitRequest) {
        do {
            let id = request.id
            let descriptor = FetchDescriptor<DropSplit>(predicate: #Predicate { $0.requestID == id })
            if try modelContext.fetchCount(descriptor) == 0 {
                modelContext.insert(DropSplit(
                    requestID: id,
                    direction: DropSplitDirection.owedToMe,
                    counterpartyName: request.recipientName,
                    transactionNote: request.transactionNote,
                    category: request.category,
                    paymentMethod: request.paymentMethod,
                    transactionAmount: request.transactionAmount,
                    amountOwed: request.amountOwed,
                    payeeName: request.payerName,
                    payeeUPI: request.payerUPI,
                    createdAt: request.createdAt
                ))
            }
            payment.splits = names.map { PaymentSplit(personName: $0, amountShare: share) }
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(dismissAfterSave: Bool) {
        for split in payment.splits ?? [] { modelContext.delete(split) }
        payment.splits = names.map { PaymentSplit(personName: $0, amountShare: share) }
        do {
            try modelContext.save()
            if dismissAfterSave { dismiss() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct DropSplitActivityView: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            DispatchQueue.main.async { onComplete(completed) }
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
