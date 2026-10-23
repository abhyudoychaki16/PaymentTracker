import Foundation
import SwiftData
import UserNotifications

enum DropSplitService {
    static func makeShareURL(for request: DropSplitRequest) throws -> URL {
        let data = try JSONEncoder().encode(request)
        let payload = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        var components = URLComponents()
        components.scheme = "dropsplit"
        components.host = "request"
        components.queryItems = [URLQueryItem(name: "payload", value: payload)]
        guard let url = components.url else { throw DropSplitError.invalidRequest }
        return url
    }

    static func request(from url: URL) throws -> DropSplitRequest {
        guard url.scheme?.lowercased() == "dropsplit",
              url.host?.lowercased() == "request",
              let payload = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "payload" })?.value else {
            throw DropSplitError.invalidRequest
        }

        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64) else { throw DropSplitError.invalidRequest }
        let request = try JSONDecoder().decode(DropSplitRequest.self, from: data)
        guard UUID(uuidString: request.id) != nil,
              !request.payerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !request.recipientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              request.amountOwed.isFinite, request.amountOwed > 0,
              request.transactionAmount.isFinite, request.transactionAmount >= request.amountOwed,
              !request.transactionNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              isValidUPI(request.payerUPI) else {
            throw DropSplitError.invalidRequest
        }
        return request
    }

    @MainActor
    static func receive(_ request: DropSplitRequest, into context: ModelContext) throws -> Bool {
        let id = request.id
        let descriptor = FetchDescriptor<DropSplit>(predicate: #Predicate { $0.requestID == id })
        guard try context.fetchCount(descriptor) == 0 else { return false }

        let entry = DropSplit(
            requestID: request.id,
            direction: DropSplitDirection.iOwe,
            counterpartyName: request.payerName,
            transactionNote: request.transactionNote,
            category: request.category,
            paymentMethod: request.paymentMethod,
            transactionAmount: request.transactionAmount,
            amountOwed: request.amountOwed,
            payeeName: request.payerName,
            payeeUPI: request.payerUPI,
            createdAt: request.createdAt
        )
        context.insert(entry)
        do {
            try context.save()
            return true
        } catch {
            context.delete(entry)
            throw error
        }
    }

    static func isValidUPI(_ value: String) -> Bool {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.range(of: #"^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9.-]{1,63}$"#, options: .regularExpression) != nil
    }

    static func paymentURL(upiID: String, payee: String, amount: Double, note: String) -> URL? {
        guard isValidUPI(upiID), amount > 0, amount.isFinite else { return nil }
        var components = URLComponents()
        components.scheme = "upi"
        components.host = "pay"
        components.queryItems = [
            URLQueryItem(name: "pa", value: upiID.trimmingCharacters(in: .whitespacesAndNewlines)),
            URLQueryItem(name: "pn", value: payee),
            URLQueryItem(name: "am", value: String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), amount)),
            URLQueryItem(name: "cu", value: "INR"),
            URLQueryItem(name: "tn", value: String(note.prefix(70)))
        ]
        return components.url
    }
}

@MainActor
enum DropSplitSMSMatcher {
    /// Exact UPI amounts are surfaced as a review suggestion. The user still
    /// confirms settlement so an unrelated credit cannot silently clear a debt.
    static func suggestMatch(for payment: Payment, in context: ModelContext) {
        guard payment.paymentMethod.caseInsensitiveCompare("UPI") == .orderedSame,
              !payment.isFlaggedAsBill else { return }
        let direction = payment.isInflow ? DropSplitDirection.owedToMe : DropSplitDirection.iOwe
        let descriptor = FetchDescriptor<DropSplit>()
        guard let entries = try? context.fetch(descriptor) else { return }
        let unpaid = entries.filter { !$0.isPaid && $0.direction == direction }
        let groups = Dictionary(grouping: unpaid, by: \.counterpartyName)
        let amountCents = Int((payment.amount * 100).rounded())
        let paymentText = normalized(payment.note)

        let candidates = groups.compactMap { name, group -> (String, [DropSplit])? in
            let groupCents = Int((group.reduce(0) { $0 + $1.amountOwed } * 100).rounded())
            guard groupCents == amountCents else { return nil }
            if direction == DropSplitDirection.iOwe {
                let normalizedName = normalized(name)
                guard !normalizedName.isEmpty, paymentText.contains(normalizedName) else { return nil }
            }
            return (name, group)
        }

        // Do not guess if the same exact amount could settle more than one person.
        guard candidates.count == 1, let fingerprint = payment.importFingerprint else { return }
        candidates[0].1.forEach { $0.smsConfirmationFingerprint = fingerprint }
        try? context.save()
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

enum DropSplitError: LocalizedError {
    case invalidRequest

    var errorDescription: String? {
        "This DropSplit link is incomplete or invalid. Ask the sender to share it again."
    }
}

enum DropSplitNotifications {
    static func notifyReceived(_ request: DropSplitRequest) async {
        guard UserDefaults.standard.bool(forKey: "dropsplit.notificationsEnabled") else { return }
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let allowed: Bool
        if isAuthorized {
            allowed = true
        } else {
            allowed = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        }
        guard allowed else { return }

        let content = UNMutableNotificationContent()
        content.title = "New DropSplit from \(request.payerName)"
        content.body = "\(request.amountOwed.formatted(.currency(code: PaymentPreferences.currencyCode))) for \(request.transactionNote). Tap to review and pay."
        content.sound = .default
        content.userInfo = ["dropsplit.requestID": request.id]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let notification = UNNotificationRequest(identifier: "dropsplit-\(request.id)", content: content, trigger: trigger)
        try? await center.add(notification)
    }
}
