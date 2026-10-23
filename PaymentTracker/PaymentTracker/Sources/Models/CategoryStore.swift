import Foundation
import Combine
import SwiftData

@MainActor
final class CategoryStore: ObservableObject {
    static let defaults = ["Uncategorized", "Food", "Transport", "Shopping", "Bills", "Health", "Entertainment", "Travel", "Other"]
    static let methods = ["Unknown", "Card", "UPI", "Cash", "Bank Transfer", "Other"]
    private let storageKey = "paymenttracker.categories.v1"
    @Published private(set) var categories: [String]

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String].self, from: data), !saved.isEmpty {
            categories = Self.normalized(saved)
        } else {
            categories = Self.defaults
        }
    }

    func add(_ name: String) throws {
        let value = try Self.validate(name)
        guard !categories.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) else {
            throw CategoryStoreError.duplicate
        }
        categories.append(value)
        persist()
    }

    func rename(_ old: String, to name: String, payments: [Payment], context: ModelContext) throws {
        guard old != "Uncategorized", let index = categories.firstIndex(of: old) else { throw CategoryStoreError.reserved }
        let value = try Self.validate(name)
        guard !categories.contains(where: { $0 != old && $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) else {
            throw CategoryStoreError.duplicate
        }
        categories[index] = value
        payments.filter { $0.category == old }.forEach { $0.category = value }
        persist()
        try context.save()
    }

    func delete(_ name: String, payments: [Payment], context: ModelContext) throws {
        guard name != "Uncategorized", categories.contains(name) else { throw CategoryStoreError.reserved }
        categories.removeAll { $0 == name }
        payments.filter { $0.category == name }.forEach { $0.category = "Uncategorized" }
        persist()
        try context.save()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(categories) { UserDefaults.standard.set(data, forKey: storageKey) }
    }

    private static func normalized(_ values: [String]) -> [String] {
        var result = ["Uncategorized"]
        for value in values where value != "Uncategorized" && !result.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) {
            result.append(value)
        }
        return result
    }

    private static func validate(_ value: String) throws -> String {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty, cleaned.count <= 32 else { throw CategoryStoreError.invalid }
        return cleaned
    }
}

enum CategoryStoreError: LocalizedError {
    case invalid, duplicate, reserved
    var errorDescription: String? {
        switch self {
        case .invalid: "Enter a category name up to 32 characters."
        case .duplicate: "A category with that name already exists."
        case .reserved: "Uncategorized is required and cannot be changed."
        }
    }
}
