import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @EnvironmentObject private var categoryStore: CategoryStore
    @Environment(\.modelContext) private var modelContext
    @Query private var payments: [Payment]
    @State private var newName = ""
    @State private var editingCategory: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Add category") {
                HStack {
                    TextField("Category name", text: $newName)
                        .textInputAutocapitalization(.words)
                    Button("Add", action: addCategory).disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Your categories") {
                ForEach(categoryStore.categories, id: \.self) { category in
                    HStack {
                        Label(category, systemImage: category == "Uncategorized" ? "tray" : "tag.fill")
                        Spacer()
                        if category == "Uncategorized" {
                            Text("Required").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Menu {
                                Button("Rename", systemImage: "pencil") { beginRename(category) }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(category) }
                            } label: { Image(systemName: "ellipsis.circle").foregroundStyle(.secondary) }
                        }
                    }
                    .tint(categoryColor(category))
                }
            }
            Section {
                Text("Deleting a category moves its transactions back to Uncategorized.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Categories")
        .alert("Category", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .alert("Rename category", isPresented: Binding(get: { editingCategory != nil }, set: { if !$0 { editingCategory = nil } })) {
            TextField("Name", text: $newName)
            Button("Cancel", role: .cancel) { editingCategory = nil; newName = "" }
            Button("Save") { renameCategory() }
        } message: { Text("Existing transactions will keep this category under its new name.") }
    }

    private func addCategory() {
        do { try categoryStore.add(newName); newName = "" }
        catch { errorMessage = error.localizedDescription }
    }

    private func beginRename(_ category: String) {
        newName = category
        editingCategory = category
    }

    private func renameCategory() {
        guard let old = editingCategory else { return }
        do { try categoryStore.rename(old, to: newName, payments: payments, context: modelContext); newName = ""; editingCategory = nil }
        catch { editingCategory = nil; errorMessage = error.localizedDescription }
    }

    private func delete(_ name: String) {
        do { try categoryStore.delete(name, payments: payments, context: modelContext) }
        catch { errorMessage = error.localizedDescription }
    }
}

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var categoryStore: CategoryStore
    let payment: Payment
    @State private var amountText: String
    @State private var note: String
    @State private var category: String
    @State private var method: String
    @State private var isInflow: Bool
    @State private var isFlaggedAsBill: Bool
    @State private var errorMessage: String?

    init(payment: Payment) {
        self.payment = payment
        _amountText = State(initialValue: String(payment.amount))
        _note = State(initialValue: payment.note)
        _category = State(initialValue: payment.category)
        _method = State(initialValue: payment.paymentMethod)
        _isInflow = State(initialValue: payment.isInflow)
        _isFlaggedAsBill = State(initialValue: payment.isFlaggedAsBill)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction details") {
                    Picker("Type", selection: $isInflow) {
                        Text("Expense").tag(false); Text("Income").tag(true)
                    }.pickerStyle(.segmented)
                    TextField("Amount", text: $amountText).keyboardType(.decimalPad)
                    TextField("Description / vendor", text: $note)
                    if !isInflow {
                        Picker("Category", selection: $category) {
                            ForEach(categoryOptions, id: \.self) { Text($0) }
                        }
                    } else {
                        LabeledContent("Category", value: "Not used for income")
                    }
                    Picker("Payment method", selection: $method) {
                        ForEach(methodOptions, id: \.self) { Text($0) }
                    }
                    if !isInflow {
                        Toggle("Credit card bill payment", isOn: $isFlaggedAsBill)
                        Text("Bill payments are kept out of your spending totals and charts.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    DatePicker("Date", selection: Binding(get: { payment.timestamp }, set: { payment.timestamp = $0 }), displayedComponents: [.date, .hourAndMinute])
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private var categoryOptions: [String] { categoryStore.categories.contains(category) ? categoryStore.categories : [category] + categoryStore.categories }
    private var methodOptions: [String] { CategoryStore.methods.contains(method) ? CategoryStore.methods : [method] + CategoryStore.methods }

    private func save() {
        guard let amount = Double(amountText.replacingOccurrences(of: ",", with: ".")), amount > 0 else { errorMessage = "Enter a valid amount."; return }
        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { errorMessage = "Add a description."; return }
        payment.amount = amount; payment.note = cleaned; payment.category = isInflow ? "Uncategorized" : category; payment.paymentMethod = method; payment.isInflow = isInflow; payment.isFlaggedAsBill = isInflow ? false : isFlaggedAsBill
        do { try modelContext.save(); dismiss() } catch { errorMessage = error.localizedDescription }
    }
}

private func categoryColor(_ category: String) -> Color {
    let colors: [Color] = [.purple, .orange, .blue, .green, .pink, .teal]
    return colors[abs(category.hashValue) % colors.count]
}
