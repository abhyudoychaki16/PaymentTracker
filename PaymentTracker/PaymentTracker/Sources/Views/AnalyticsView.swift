import SwiftUI
import SwiftData
import Charts

struct AnalyticsView: View {
    @Query(sort: \Payment.timestamp, order: .reverse) private var payments: [Payment]
    @EnvironmentObject private var categoryStore: CategoryStore
    @State private var startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: .now)) ?? .now
    @State private var endDate = Date.now
    @State private var searchText = ""
    @State private var dimension = BreakdownDimension.category
    @State private var selectedValue = "All"
    @State private var editingPayment: Payment?

    private var dateFiltered: [Payment] {
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
        return payments.filter { $0.timestamp >= Calendar.current.startOfDay(for: startDate) && $0.timestamp < end }
    }
    private var searched: [Payment] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return dateFiltered }
        return dateFiltered.filter { $0.note.localizedStandardContains(searchText) }
    }
    private var filterOptions: [String] {
        let values = dimension == .category ? categoryStore.categories : CategoryStore.methods
        return ["All"] + values
    }
    private var filtered: [Payment] {
        guard selectedValue != "All" else { return searched }
        return searched.filter { dimension.value(for: $0) == selectedValue }
    }
    private var expenses: [Payment] { filtered.filter { !$0.isInflow && !$0.isFlaggedAsBill } }
    private var income: [Payment] { filtered.filter(\.isInflow) }
    private var totalSpent: Double { expenses.reduce(0) { $0 + $1.amount } }
    private var totalIncome: Double { income.reduce(0) { $0 + $1.amount } }
    private var breakdownDimension: BreakdownDimension { dimension == .category ? .paymentMethod : .category }
    private var chartItems: [ChartItem] {
        Dictionary(grouping: expenses, by: { breakdownDimension.value(for: $0) })
            .map { ChartItem(name: $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }
    }
    private var currencyCode: String { PaymentPreferences.currencyCode }
    private let palette: [Color] = [.purple, .pink, .orange, .teal, .blue, .green, .indigo, .mint]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                filtersCard
                HStack(spacing: 12) {
                    colorfulMetric("Spent", value: totalSpent, color: .orange, icon: "arrow.up.right")
                    colorfulMetric("Income", value: totalIncome, color: .green, icon: "arrow.down.left")
                }
                breakdownCard
                transactionsCard
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Analytics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { CategoryManagementView() } label: { Label("Categories", systemImage: "tag") }
            }
        }
        .sheet(item: $editingPayment) { payment in TransactionEditorView(payment: payment) }
        .onChange(of: dimension) { _, _ in selectedValue = "All" }
        .onChange(of: filterOptions) { _, values in if !values.contains(selectedValue) { selectedValue = "All" } }
    }

    private var filtersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Refine your view", systemImage: "slider.horizontal.3")
                .font(.headline).foregroundStyle(.teal)
            Text("Choose a period, then compare spending by category or payment method.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact).labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact).labelsHidden().frame(maxWidth: .infinity, alignment: .trailing)
            }
            HStack(spacing: 7) {
                rangeButton("7D", days: 7)
                rangeButton("30D", days: 30)
                rangeButton("90D", days: 90)
                Button("All time") { startDate = .distantPast; endDate = .now }
                    .font(.caption.weight(.semibold)).buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Split by").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Picker("Split by", selection: $dimension) {
                        ForEach(BreakdownDimension.allCases) {
                            Text($0.title).lineLimit(1).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 12)
                    .paymentGlass(in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Show").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Picker("Show", selection: $selectedValue) {
                        ForEach(filterOptions, id: \.self) {
                            Text($0).lineLimit(1).tag($0)
                        }
                    }
                    .pickerStyle(.menu)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 12)
                    .paymentGlass(in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Vendor or person", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                if !searchText.isEmpty { Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }.foregroundStyle(.secondary) }
            }
            .padding(12)
            .paymentGlass(in: RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
            Text(selectedValue == "All" ? "Expenses split by \(breakdownDimension.title.lowercased())" : "\(selectedValue) split by \(breakdownDimension.title.lowercased())")
                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(16)
        .paymentGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Spending breakdown").font(.headline)
                    Text("By \(breakdownDimension.title.lowercased())").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: dimension == .category ? "creditcard.fill" : "square.grid.2x2.fill")
                    .foregroundStyle(.white).padding(10)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
            }
            if chartItems.isEmpty {
                ContentUnavailableView("No matching expenses", systemImage: "chart.pie", description: Text("Try another date range or filter."))
                    .frame(height: 210)
            } else {
                Chart {
                    ForEach(chartItems.indices, id: \.self) { index in
                        let item = chartItems[index]
                        SectorMark(
                            angle: .value("Amount", item.amount),
                            innerRadius: .ratio(0.62),
                            outerRadius: .ratio(1),
                            angularInset: 2
                        )
                        .foregroundStyle(palette[index % palette.count].gradient)
                        .cornerRadius(4)
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 210)
                .overlay {
                    VStack(spacing: 3) {
                        Text("TOTAL").font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(.secondary)
                        Text(totalSpent, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                            .font(.system(size: 18, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
                    }
                    .padding(8)
                }
                VStack(spacing: 9) {
                    ForEach(chartItems.indices, id: \.self) { index in
                        let item = chartItems[index]
                        HStack(spacing: 9) {
                            Circle().fill(palette[index % palette.count]).frame(width: 9, height: 9)
                            Text(item.name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(item.amount, format: .currency(code: currencyCode))
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(percentage(item.amount, of: totalSpent))
                                .font(.caption.weight(.bold)).frame(width: 42, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .padding(16).paymentGlass(in: RoundedRectangle(cornerRadius: 20))
    }

    private var transactionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Transactions").font(.headline)
                Spacer()
                Text("\(filtered.count)").font(.caption.weight(.bold)).foregroundStyle(.white).padding(.horizontal, 9).padding(.vertical, 5).background(.indigo, in: Capsule())
            }
            if filtered.isEmpty {
                Text("No transactions match these filters.").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 10)
            } else {
                ForEach(filtered) { payment in
                    Button { editingPayment = payment } label: {
                        TransactionRow(payment: payment)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(16).paymentGlass(in: RoundedRectangle(cornerRadius: 20))
    }

    private func colorfulMetric(_ title: String, value: Double, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
            Text(value, format: .currency(code: currencyCode)).font(.title3.bold()).minimumScaleFactor(0.65).lineLimit(1).foregroundStyle(.white)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [color, color.opacity(0.68)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 18))
    }

    private func rangeButton(_ title: String, days: Int) -> some View {
        Button(title) {
            endDate = .now
            startDate = Calendar.current.date(byAdding: .day, value: -days + 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        }.font(.caption.weight(.semibold)).buttonStyle(.bordered).frame(maxWidth: .infinity)
    }

    private func percentage(_ value: Double, of total: Double) -> String {
        guard total > 0 else { return "0%" }
        return (value / total).formatted(.percent.precision(.fractionLength(0)))
    }
}

private enum BreakdownDimension: String, CaseIterable, Identifiable {
    case category, paymentMethod
    var id: String { rawValue }
    var title: String { self == .category ? "Category" : "Payment method" }
    func value(for payment: Payment) -> String { self == .category ? payment.category : payment.paymentMethod }
}

private struct ChartItem {
    let name: String
    let amount: Double
}
