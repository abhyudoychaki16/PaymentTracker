import Foundation

final class MessageScanner {
    /// Parses a bank transaction alert. A currency amount and a payment-related
    /// word are not enough: require both a completed transaction event and
    /// evidence that the message came from a bank/payment rail.
    func parseTransaction(message: String) -> ParsedPaymentMessage? {
        let normalized = message.lowercased()
        guard hasCompletedTransactionEvent(in: normalized),
              hasFinancialInstitutionEvidence(in: normalized),
              let amount = extractAmount(from: message), amount > 0 else { return nil }

        let isInflow = containsAny(normalized, ["credited", "received", "deposited", "reversal", "reversed"])
        let isCardBillPayment = isBillPayment(normalized)
        let method = inferPaymentMethod(from: normalized)

        return ParsedPaymentMessage(
            amount: amount,
            note: extractMerchant(from: message) ?? (isCardBillPayment ? "Credit card bill payment" : "Bank transaction"),
            category: inferCategory(from: normalized),
            isInflow: isInflow,
            paymentMethod: method,
            isCardBillPayment: isCardBillPayment,
            timestamp: extractTimestamp(from: message)
        )
    }

    func scan(message: String) -> PaymentAnalysis? {
        guard parseTransaction(message: message) != nil else { return nil }
        return PaymentAnalysis(isPayment: true, message: message)
    }

    private func hasCompletedTransactionEvent(in message: String) -> Bool {
        // These indicate a completed debit or credit. Bare terms such as
        // "payment due", "UPI offer", or "card payment options" are rejected.
        containsAny(message, ["spent", "sent", "debited", "credited", "received", "deposited", "reversal", "reversed", "transferred", "withdrawn"]) ||
            message.range(of: #"\bpaid\s+(?:rs\.?|inr|₹)?\s*\d"#, options: .regularExpression) != nil ||
            message.range(of: #"\b(?:payment|transaction)\b[\s\S]{0,60}\b(?:successful|succeeded|processed|completed|paid)\b"#, options: .regularExpression) != nil
    }

    private func hasFinancialInstitutionEvidence(in message: String) -> Bool {
        let financialMarkers = [
            "bank", "a/c", "account", "upi", "vpa", "neft", "imps", "rtgs", "ifsc",
            "hdfc", "icici", "sbi", "state bank", "axis", "kotak", "yes bank", "indusind",
            "idfc", "federal bank", "bank of baroda", "canara", "union bank", "paytm payments bank"
        ]
        if containsAny(message, financialMarkers) { return true }
        return message.range(of: #"\b(?:debit|credit)\s+card\b|\bcard\s*(?:ending|no\.?|number|#|[x*•]?\s*\d{2,4})\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func extractAmount(from message: String) -> Double? {
        let currency = #"(?:₹|\bINR\b|\bRs\.?\s*)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
        let patterns = [
            // Common alert layouts: "Spent Rs.123", "Sent Rs 123", "Rs.123 credited".
            #"\b(?:spent|sent|debited|credited|received|deposited|paid|transferred|withdrawn|payment|transaction)\b[\s\S]{0,40}?"# + currency,
            currency + #"[\s\S]{0,60}?\b(?:debited|credited|received|deposited|paid|transferred|withdrawn|payment|transaction)\b"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
                  let range = Range(match.range(at: 1), in: message) else { continue }
            let value = message[range].replacingOccurrences(of: ",", with: "")
            if let amount = Double(value), amount.isFinite { return amount }
        }
        return nil
    }

    private func extractMerchant(from message: String) -> String? {
        let vpaPattern = #"\bfrom\s+VPA\s+([^\s(]+)"#
        if let regex = try? NSRegularExpression(pattern: vpaPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message) {
            let sender = message[range].trimmingCharacters(in: CharacterSet(charactersIn: "*._- "))
            if !sender.isEmpty { return "UPI from \(sender)" }
        }

        // Prefer the merchant after "At" for cards, and the payee after "To" for UPI.
        let pattern = #"\b(?:at|to|towards)\s+([A-Za-z0-9][A-Za-z0-9 &'._*-]{0,35}?)(?:\s+(?:on|via|using|ref|UPI|from|not you)\b|[.,;]|$)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
              let range = Range(match.range(at: 1), in: message) else { return nil }
        let merchant = message[range]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "*._- "))
        return merchant.isEmpty ? nil : merchant
    }

    private func inferCategory(from message: String) -> String {
        let keywords: [(String, [String])] = [
            ("Dining", ["restaurant", "cafe", "coffee", "food", "swiggy", "zomato", "dining"]),
            ("Transport", ["uber", "ola", "rapido", "metro", "fuel", "petrol", "parking", "transit"]),
            ("Shopping", ["amazon", "flipkart", "shopping", "retail", "marketplace"]),
            ("Entertainment", ["netflix", "spotify", "cinema", "movie", "theatre", "entertainment"]),
            ("Health", ["pharmacy", "medical", "hospital", "clinic", "health"]),
            ("Travel", ["airline", "flight", "hotel", "airbnb", "booking.com", "travel"]),
            ("Bills", ["electricity", "water bill", "gas bill", "utility", "broadband", "internet bill", "recharge"])
        ]
        for (category, terms) in keywords where terms.contains(where: message.contains) { return category }
        return "Other"
    }

    private func inferPaymentMethod(from message: String) -> String {
        if message.contains("card") { return "Card" }
        if containsAny(message, ["upi", "vpa"]) { return "UPI" }
        if message.contains("cash") { return "Cash" }
        if containsAny(message, ["transfer", "neft", "imps", "rtgs"]) { return "Bank Transfer" }
        return "Unknown"
    }

    private func isBillPayment(_ message: String) -> Bool {
        (message.contains("credit card") || message.contains("card bill")) &&
            containsAny(message, ["bill", "statement"])
    }

    private func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { term in
            text.range(of: #"\b\#(NSRegularExpression.escapedPattern(for: term))\b"#, options: .regularExpression) != nil
        }
    }

    private func extractTimestamp(from message: String) -> Date? {
        let patterns: [(String, String)] = [
            (#"\b\d{4}-\d{2}-\d{2}:\d{2}:\d{2}:\d{2}\b"#, "yyyy-MM-dd:HH:mm:ss"),
            (#"\b\d{4}-\d{2}-\d{2}:\d{2}:\d{2}\b"#, "yyyy-MM-dd:HH:mm"),
            (#"\b\d{2}/\d{2}/\d{2}\b"#, "dd/MM/yy"),
            (#"\b\d{2}-\d{2}-\d{2}\b"#, "dd-MM-yy")
        ]
        for (pattern, format) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
                  let range = Range(match.range, in: message) else { continue }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: String(message[range])) { return date }
        }
        return nil
    }
}

struct PaymentAnalysis {
    let isPayment: Bool
    let message: String
}

struct ParsedPaymentMessage {
    let amount: Double
    let note: String
    let category: String
    let isInflow: Bool
    let paymentMethod: String
    let isCardBillPayment: Bool
    let timestamp: Date?
}
