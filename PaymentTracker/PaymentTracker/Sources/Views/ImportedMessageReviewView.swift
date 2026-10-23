import SwiftUI
import SwiftData

/// A centered, in-app confirmation shown after a payment alert is imported.
/// iOS does not let an app present this custom UI while it is backgrounded.
struct ImportedMessageReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let message: String
    let onComplete: () -> Void

    @State private var result: ImportResult = .processing
    @State private var didProcess = false

    private var parsed: ParsedPaymentMessage? {
        MessageScanner().parseTransaction(message: message)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { }

            popupCard
                .padding(.horizontal, 28)
                .frame(maxWidth: 420)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .accessibilityAddTraits(.isModal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: processMessage)
    }

    @ViewBuilder
    private var popupCard: some View {
        VStack(spacing: 18) {
            switch result {
            case .processing:
                ProgressView()
                    .controlSize(.large)
                    .tint(.blue)
                Text("Adding transaction…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            case .saved(let amount, let note, let category, let isInflow):
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 76, height: 76)
                    Image(systemName: "checkmark")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)

                VStack(spacing: 6) {
                    Text("Added to PaymentTracker")
                        .font(.title3.bold())
                        .multilineTextAlignment(.center)
                    Text(isInflow ? "Money received" : "Expense recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    Text(amount, format: .currency(code: currencyCode))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Divider()
                    HStack(spacing: 11) {
                        Image(systemName: "storefront.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 38, height: 38)
                            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note).font(.headline).lineLimit(1)
                            Text("Saved under \(category)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button(action: onComplete) {
                    Text("Done")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Color.blue.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            case .failed(let reason):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.orange)
                Text("Couldn’t add this transaction")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Close", action: onComplete)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .buttonStyle(.borderedProminent)
            case .duplicate:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.teal)
                Text("Already added")
                    .font(.title3.bold())
                Text("This bank message was imported earlier.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Close", action: onComplete)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 32, y: 16)
    }

    private var currencyCode: String {
        PaymentPreferences.currencyCode
    }

    private func processMessage() {
        guard !didProcess else { return }
        didProcess = true
        guard parsed != nil else {
            result = .failed("The message did not contain a recognizable payment and amount.")
            return
        }

        do {
            switch try PaymentMessageImporter.importMessage(message, into: modelContext) {
            case .saved(let payment):
                result = .saved(amount: payment.amount, note: payment.note, category: payment.category, isInflow: payment.isInflow)
            case .duplicate:
                result = .duplicate
            case .ignored:
                result = .failed("The message did not contain a recognizable bank transaction.")
            }
        } catch {
            result = .failed(error.localizedDescription)
        }
    }
}

private enum ImportResult {
    case processing
    case saved(amount: Double, note: String, category: String, isInflow: Bool)
    case failed(String)
    case duplicate
}
