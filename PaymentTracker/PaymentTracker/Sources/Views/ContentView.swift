import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Payment.timestamp, order: .reverse) private var payments: [Payment]
    @State private var showingAddPayment = false
    @State private var selectedPayment: Payment?
    @State private var editingPayment: Payment?
    @State private var errorMessage: String?
    @State private var selectedPeriod = DashboardPeriod(rawValue: UserDefaults.standard.string(forKey: "dashboard.defaultPeriod") ?? "today") ?? .today
    @State private var periodBeforeCustomRange = DashboardPeriod.today
    @State private var showingCustomRange = false
    @State private var customStartDate = Calendar.current.date(byAdding: .day, value: -29, to: Calendar.current.startOfDay(for: .now)) ?? .now
    @State private var customEndDate = Calendar.current.startOfDay(for: .now)
    @State private var selectedSection: MainSection = .home
    @AppStorage("dashboard.defaultPeriod") private var defaultPeriodPreference = "today"

    private var periodStart: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        switch selectedPeriod {
        case .today: return today
        case .sevenDays: return calendar.date(byAdding: .day, value: -6, to: today) ?? today
        case .thirtyDays: return calendar.date(byAdding: .day, value: -29, to: today) ?? today
        case .custom: return calendar.startOfDay(for: min(customStartDate, customEndDate))
        }
    }
    private var periodEndExclusive: Date {
        let calendar = Calendar.current
        let end = selectedPeriod == .custom ? max(customStartDate, customEndDate) : .now
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
    }
    private var periodPayments: [Payment] {
        payments.filter { $0.timestamp >= periodStart && $0.timestamp < periodEndExclusive }
    }
    private var periodExpenses: [Payment] { periodPayments.filter { !$0.isInflow && !$0.isFlaggedAsBill } }
    private var periodSpent: Double { periodExpenses.reduce(0) { $0 + $1.amount } }
    private var periodIncome: Double { periodPayments.filter(\.isInflow).reduce(0) { $0 + $1.amount } }
    private var currencyCode: String { PaymentPreferences.currencyCode }

    var body: some View {
        NavigationStack {
            Group {
                switch selectedSection {
                case .home: homeContent
                case .analytics: AnalyticsView()
                case .splits: DropSplitInboxView()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                sectionSwitcher
            }
            .onChange(of: defaultPeriodPreference) { _, value in
                if let period = DashboardPeriod(rawValue: value), period != .custom {
                    selectedPeriod = period
                }
            }
            .onChange(of: selectedPeriod) { _, period in
                if period != .custom { defaultPeriodPreference = period.rawValue }
            }
            .background {
                ZStack {
                    Color(uiColor: .systemGroupedBackground)
                    LinearGradient(
                        colors: [Color.teal.opacity(0.08), .clear, Color.blue.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .ignoresSafeArea()
            }
            .navigationTitle(selectedSection.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedSection == .home {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink { MessageImportHelpView() } label: {
                            Image(systemName: "message.badge").accessibilityLabel("Message import setup")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { SettingsView() } label: {
                            Image(systemName: "gearshape").accessibilityLabel("Settings")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddPayment) { PaymentFormView() }
            .sheet(isPresented: $showingCustomRange) { customRangeSheet }
            .sheet(item: $selectedPayment) { payment in
                NavigationStack { SplitPaymentView(payment: payment) }
            }
            .sheet(item: $editingPayment) { payment in
                TransactionEditorView(payment: payment)
            }
            .alert("Couldn’t update transaction", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "Please try again.") }
        }
    }

    private var homeContent: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    periodPicker
                    overviewCard
                    quickActions
                    recentTransactions
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }

    private var sectionSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(MainSection.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selectedSection = section }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: selectedSection == section ? section.selectedIcon : section.icon)
                            .font(.system(size: 17, weight: .semibold))
                        Text(section.shortTitle)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(selectedSection == section ? Color.teal : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Rectangle())
                    .background {
                        if selectedSection == section {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.teal.opacity(0.12))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selectedSection == section ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.primary.opacity(0.06), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 7)
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.clear)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                Text("Your money, in focus")
                    .font(.system(size: 28, weight: .bold, design: .rounded)).tracking(-0.5)
            }
            Spacer()
            Image(systemName: "chart.pie.fill")
                .font(.title3.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var periodPicker: some View {
        Picker("Transaction period", selection: $selectedPeriod) {
            ForEach(DashboardPeriod.allCases) { period in
                Text(period.title).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("dashboard.period.picker")
        .onChange(of: selectedPeriod) { previous, selected in
            guard selected == .custom else { return }
            periodBeforeCustomRange = previous
            showingCustomRange = true
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }

    private var customRangeSheet: some View {
        NavigationStack {
            Form {
                Section("Date range") {
                    DatePicker("From", selection: $customStartDate, in: ...Date.now, displayedComponents: .date)
                    DatePicker("To", selection: $customEndDate, in: ...Date.now, displayedComponents: .date)
                }
                Section {
                    Text("Showing transactions from \(customStartDate.formatted(date: .abbreviated, time: .omitted)) to \(customEndDate.formatted(date: .abbreviated, time: .omitted)).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Custom date range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedPeriod = periodBeforeCustomRange
                        showingCustomRange = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingCustomRange = false }
                }
            }
            .onChange(of: customStartDate) { _, start in
                if customEndDate < start { customEndDate = start }
            }
            .onChange(of: customEndDate) { _, end in
                if customStartDate > end { customStartDate = end }
            }
            .presentationDetents([.medium])
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label(selectedPeriod == .custom ? "CUSTOM PERIOD" : selectedPeriod.title.uppercased(), systemImage: "calendar")
                    .font(.caption.weight(.bold)).tracking(1.1).foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text("\(periodPayments.count) items")
                    .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.82))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(periodSpent, format: .currency(code: currencyCode))
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.65).lineLimit(1)
                Text("spent in this period").font(.subheadline).foregroundStyle(.white.opacity(0.78))
            }
            Rectangle().fill(.white.opacity(0.18)).frame(height: 1)
            HStack(spacing: 0) {
                overviewMetric("Income", amount: periodIncome, icon: "arrow.down.left", tint: .mint)
                Spacer(minLength: 14)
                overviewMetric("Expenses", amount: Double(periodExpenses.count), icon: "arrow.up.right", tint: .white, isCount: true)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(red: 0.04, green: 0.28, blue: 0.34), Color(red: 0.05, green: 0.48, blue: 0.52), Color(red: 0.12, green: 0.36, blue: 0.64)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.06)).frame(width: 180).offset(x: 45, y: -70)
                Circle().stroke(.white.opacity(0.08), lineWidth: 1).frame(width: 240).offset(x: 65, y: -100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .shadow(color: Color.teal.opacity(0.16), radius: 18, y: 9)
    }

    private func overviewMetric(_ title: String, amount: Double, icon: String, tint: Color, isCount: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.caption.weight(.bold)).foregroundStyle(tint)
                .frame(width: 32, height: 32).background(.white.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.white.opacity(0.72))
                Text(isCount ? String(Int(amount)) : amount.formatted(.currency(code: currencyCode)))
                    .font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private var quickActions: some View {
        Button { showingAddPayment = true } label: {
            Label("Add transaction", systemImage: "plus")
                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent).tint(.teal)
    }

    private var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedPeriod == .today ? "Today’s transactions" : "Transactions")
                        .font(.title3.bold())
                    Text("\(periodPayments.count) in \(selectedPeriod.title.lowercased())")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !periodPayments.isEmpty {
                    Button("See all") { selectedSection = .analytics }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(.teal)
                }
            }
            if periodPayments.isEmpty {
                ContentUnavailableView(
                    selectedPeriod == .today ? "No transactions today" : "No transactions in this period",
                    systemImage: "creditcard",
                    description: Text("Change the date range or add a transaction to get started.")
                )
                .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(periodPayments.prefix(8)) { payment in
                        TransactionRow(payment: payment)
                            .contentShape(RoundedRectangle(cornerRadius: 17))
                            .onTapGesture { editingPayment = payment }
                            .contextMenu {
                                Button("Split payment", systemImage: "person.2") { selectedPayment = payment }
                                Button("Edit transaction", systemImage: "pencil") { editingPayment = payment }
                                if !payment.isInflow {
                                    Button(payment.isFlaggedAsBill ? "Unmark card bill payment" : "Mark as card bill payment", systemImage: "creditcard") {
                                        payment.isFlaggedAsBill.toggle()
                                        do { try modelContext.save() }
                                        catch { errorMessage = error.localizedDescription }
                                    }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(payment) }
                            }
                    }
                }
                if periodPayments.count > 8 {
                    Text("Showing the 8 most recent · refine the date range to narrow the list")
                        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.top, 3)
                }
            }
        }
        .padding(.top, 2)
    }

    private func delete(_ payment: Payment) {
        do { try TransactionViewModel().deletePayment(payment, from: modelContext) }
        catch { errorMessage = error.localizedDescription }
    }
}

private enum MainSection: String, CaseIterable, Identifiable {
    case home, analytics, splits

    var id: String { rawValue }
    var title: String {
        switch self {
        case .home: return "Payment Tracker"
        case .analytics: return "Analytics"
        case .splits: return "DropSplit"
        }
    }
    var shortTitle: String {
        switch self {
        case .home: return "Home"
        case .analytics: return "Analytics"
        case .splits: return "Splits"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house"
        case .analytics: return "chart.pie"
        case .splits: return "arrow.left.arrow.right"
        }
    }
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .analytics: return "chart.pie.fill"
        case .splits: return "arrow.left.arrow.right"
        }
    }
}

private enum DashboardPeriod: String, CaseIterable, Identifiable {
    case today, sevenDays, thirtyDays, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: return "Today"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .custom: return "Custom"
        }
    }
}

struct TransactionRow: View {
    let payment: Payment
    private var currencyCode: String { PaymentPreferences.currencyCode }
    private var tint: Color { payment.isInflow ? .green : (payment.isFlaggedAsBill ? .indigo : .teal) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.headline.weight(.semibold)).foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(payment.note).font(.subheadline.weight(.semibold)).lineLimit(1)
                    if payment.isFlaggedAsBill {
                        Image(systemName: "creditcard.fill").font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.indigo).accessibilityLabel("Credit card bill payment")
                    }
                }
                Text("\(payment.category) · \(payment.paymentMethod) · \(payment.timestamp.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(payment.amount, format: .currency(code: currencyCode))
                .font(.subheadline.weight(.bold)).foregroundStyle(payment.isInflow ? .green : .primary)
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(12)
        .paymentGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.primary.opacity(0.08), lineWidth: 1))
    }

    private var iconName: String {
        if payment.isFlaggedAsBill { return "creditcard" }
        if payment.isInflow { return "arrow.down.left" }
        switch payment.paymentMethod.lowercased() {
        case "card": return "creditcard"
        case "upi": return "qrcode"
        case "bank transfer": return "building.columns"
        default: return "arrow.up.right"
        }
    }
}
