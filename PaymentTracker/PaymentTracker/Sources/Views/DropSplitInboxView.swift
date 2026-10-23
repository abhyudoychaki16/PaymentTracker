import SwiftUI
import SwiftData
import UIKit

struct DropSplitInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query(sort: \DropSplit.createdAt, order: .reverse) private var splits: [DropSplit]
    @State private var errorMessage: String?
    @State private var activeConfirmation: SplitGroupConfirmation?

    private var pending: [DropSplit] { splits.filter { !$0.isPaid } }
    private var amountOwedToMe: Double { pending.filter(\.isOwedToMe).reduce(0) { $0 + $1.amountOwed } }
    private var amountIOwe: Double { pending.filter { !$0.isOwedToMe }.reduce(0) { $0 + $1.amountOwed } }
    private var currencyCode: String { PaymentPreferences.currencyCode }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summaryCard
                splitSection("I owe", direction: DropSplitDirection.iOwe)
                splitSection("Owed to me", direction: DropSplitDirection.owedToMe)
                if splits.isEmpty {
                    ContentUnavailableView(
                        "No DropSplits yet",
                        systemImage: "arrow.left.arrow.right",
                        description: Text("Open a transaction, choose Split payment, then AirDrop a request to someone.")
                    )
                    .padding(.top, 24)
                }
            }
            .padding(18)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("DropSplit")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Couldn’t update split", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "Please try again.") }
        .confirmationDialog(
            activeConfirmation?.title ?? "Mark this split as paid?",
            isPresented: Binding(
                get: { activeConfirmation != nil },
                set: { if !$0 { activeConfirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Mark paid", role: .destructive) {
                guard let confirmation = activeConfirmation else { return }
                markPaid(confirmation.splits)
                activeConfirmation = nil
            }
            Button("Cancel", role: .cancel) { activeConfirmation = nil }
        } message: {
            if let confirmation = activeConfirmation {
                Text("Mark the full \(confirmation.amount.formatted(.currency(code: currencyCode))) balance with \(confirmation.name) as paid on this phone.")
            }
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Shared expenses", systemImage: "arrow.left.arrow.right")
                .font(.caption.weight(.bold)).tracking(0.8).foregroundStyle(.white.opacity(0.78))
            Text("Keep the little things\nin balance.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 12) {
                balanceMetric(title: "You owe", amount: amountIOwe, tint: .white)
                balanceMetric(title: "Owed to you", amount: amountOwedToMe, tint: .mint)
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.03, green: 0.27, blue: 0.35), Color(red: 0.07, green: 0.43, blue: 0.52), Color(red: 0.12, green: 0.31, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func balanceMetric(title: String, amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.white.opacity(0.72))
            Text(amount, format: .currency(code: currencyCode))
                .font(.subheadline.weight(.bold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func splitSection(_ title: String, direction: String) -> some View {
        let sectionEntries = splits.filter { $0.direction == direction }
        let grouped = Dictionary(grouping: sectionEntries, by: \.counterpartyName)
        if !sectionEntries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.title3.bold())
                ForEach(grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }, id: \.self) { name in
                    if let items = grouped[name]?.sorted(by: { $0.createdAt > $1.createdAt }) {
                        groupCard(name: name, items: items)
                    }
                }
            }
        }
    }

    private func groupCard(name: String, items: [DropSplit]) -> some View {
        let unpaid = items.filter { !$0.isPaid }
        let total = unpaid.reduce(0) { $0 + $1.amountOwed }
        let owesMe = items.first?.isOwedToMe ?? false
        let smsMatched = !unpaid.isEmpty && unpaid.allSatisfy { $0.smsConfirmationFingerprint != nil }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.headline)
                    Text("\(unpaid.count) unpaid \(unpaid.count == 1 ? "split" : "splits")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(total, format: .currency(code: currencyCode))
                    .font(.headline.weight(.bold)).monospacedDigit()
            }

            ForEach(items, id: \.requestID) { split in
                HStack(spacing: 9) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(split.transactionNote).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text("\(split.category) · \(split.paymentMethod) · \(split.createdAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(split.amountOwed, format: .currency(code: currencyCode))
                        .font(.caption.weight(.semibold)).monospacedDigit()
                    if split.isPaid {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button {
                            activeConfirmation = SplitGroupConfirmation(name: name, amount: split.amountOwed, splits: [split])
                        } label: {
                            Image(systemName: "checkmark.circle")
                                .font(.title3)
                                .accessibilityLabel("Mark \(split.transactionNote) paid")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.teal)
                    }
                }
                if split.requestID != items.last?.requestID { Divider().opacity(0.45) }
            }

            if !unpaid.isEmpty {
                if smsMatched {
                    Button {
                        markPaid(unpaid)
                    } label: {
                        Label("Confirm exact UPI match from SMS", systemImage: "message.badge.filled.fill")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 38)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                }
                HStack(spacing: 10) {
                    if !owesMe, let payee = unpaid.first,
                       let url = DropSplitService.paymentURL(upiID: payee.payeeUPI, payee: payee.payeeName, amount: total, note: "DropSplit with \(name)") {
                        Button {
                            openURL(url) { accepted in
                                if !accepted { errorMessage = "No UPI payment app could open this payment. You can pay manually to \(payee.payeeUPI)." }
                            }
                        } label: {
                            Label("Pay full balance", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.borderedProminent).tint(.teal)
                        Button {
                            UIPasteboard.general.string = payee.payeeUPI
                        } label: {
                            Label("Copy UPI ID", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(owesMe ? "Mark all paid" : "I paid") {
                        activeConfirmation = SplitGroupConfirmation(name: name, amount: total, splits: unpaid)
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 42)
                }
            } else {
                Label("Settled", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundStyle(.green)
            }
        }
        .padding(15)
        .paymentGlass(in: RoundedRectangle(cornerRadius: 21, style: .continuous))
    }

    private func markPaid(_ items: [DropSplit]) {
        let now = Date.now
        items.forEach { $0.paidAt = now }
        do { try modelContext.save() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct SplitGroupConfirmation {
    let name: String
    let amount: Double
    let splits: [DropSplit]
    var title: String { "Mark payment with \(name) as done?" }
}
