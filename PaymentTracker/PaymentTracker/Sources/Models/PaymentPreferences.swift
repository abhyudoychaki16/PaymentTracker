import Foundation

enum PaymentPreferences {
    static let defaultCurrencyCode = Locale.current.currency?.identifier ?? "INR"
    static let currencyDefaultsKey = "payment.currencyCode"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "dropsplit.displayName": "",
            "dropsplit.upiID": "",
            "dropsplit.notificationsEnabled": true,
            "dashboard.defaultPeriod": "today",
            currencyDefaultsKey: defaultCurrencyCode
        ])
    }

    static var currencyCode: String {
        UserDefaults.standard.string(forKey: currencyDefaultsKey) ?? defaultCurrencyCode
    }
}
