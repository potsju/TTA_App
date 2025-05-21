import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Charts

struct ManagerFinancesView: View {
    @State private var isLoading = true
    @State private var totalRevenue = 0
    @State private var coachPayouts = 0
    @State private var netRevenue = 0
    @State private var monthlyRevenueData: [MonthlyRevenue] = []
    @State private var recentTransactions: [FinanceTransaction] = []
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingFilterSheet = false
    
    enum TimeRange: String, CaseIterable, Identifiable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case quarter = "Last 90 Days"
        case year = "Last 365 Days"
        
        var id: String { rawValue }
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    struct MonthlyRevenue: Identifiable {
        let id = UUID()
        let month: Date
        let revenue: Int
        let expenses: Int
        
        var profit: Int {
            revenue - expenses
        }
        
        var monthString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            return formatter.string(from: month)
        }
    }
    
    struct FinanceTransaction: Identifiable {
        let id: String
        let date: Date
        let description: String
        let amount: Int
        let type: TransactionType
        let relatedUserId: String?
        let userName: String?
        
        enum TransactionType: String {
            case revenue = "Revenue"
            case expense = "Expense"
            case payout = "Coach Payout"
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary cards
                    if isLoading {
                        VStack {
                            Spacer()
                            ProgressView("Loading financial data...")
                            Spacer()
                        }
                        .frame(height: 200)
                    } else {
                        // Time range picker
                        Picker("Time Range", selection: $selectedTimeRange) {
                            ForEach(TimeRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        .onChange(of: selectedTimeRange) { newValue in
                            loadFinancialData()
                        }
                        
                        HStack(spacing: 12) {
                            FinanceCard(
                                title: "Total Revenue",
                                amount: totalRevenue,
                                icon: "dollarsign.circle.fill",
                                color: .green
                            )
                            
                            FinanceCard(
                                title: "Coach Payouts",
                                amount: coachPayouts,
                                icon: "person.3.fill",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                        
                        FinanceCard(
                            title: "Net Revenue",
                            amount: netRevenue,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .blue,
                            fullWidth: true
                        )
                        .padding(.horizontal)
                        
                        // Revenue chart
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Revenue Trends")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if monthlyRevenueData.isEmpty {
                                Text("No revenue data available")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                RevenueChart(data: monthlyRevenueData)
                                    .frame(height: 200)
                                    .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        
                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Recent Transactions")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    showingFilterSheet = true
                                }) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal)
                            
                            if recentTransactions.isEmpty {
                                Text("No transactions found")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(recentTransactions) { transaction in
                                    TransactionRow(transaction: transaction)
                                        .padding(.horizontal)
                                }
                                
                                Button(action: {
                                    // View all transactions
                                }) {
                                    Text("View All Transactions")
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                                .padding(.top, 10)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Finances")
            .navigationBarItems(trailing: Button(action: {
                loadFinancialData()
            }) {
                Image(systemName: "arrow.clockwise")
            })
            .onAppear {
                loadFinancialData()
            }
            .sheet(isPresented: $showingFilterSheet) {
                TransactionFilterView(onApply: { filter in
                    // Apply the filter
                    loadFinancialData(filter: filter)
                })
            }
        }
    }
    
    private func loadFinancialData(filter: TransactionFilter? = nil) {
        isLoading = true
        
        let db = Firestore.firestore()
        let startDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date())!
        
        // Reset values
        totalRevenue = 0
        coachPayouts = 0
        
        // Get bookings (revenue)
        db.collection("bookings")
            .whereField("timestamp", isGreaterThan: startDate)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error loading bookings: \(error)")
                    return
                }
                
                var transactions: [FinanceTransaction] = []
                var revenue = 0
                
                for document in snapshot?.documents ?? [] {
                    let data = document.data()
                    let date = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Determine amount
                    var amount = 0
                    if let credits = data["credits"] as? Int {
                        amount = credits
                    } else if let cost = data["cost"] as? Int {
                        amount = cost
                    }
                    
                    if amount > 0 {
                        revenue += amount
                        
                        // Create transaction record
                        let studentName = data["studentName"] as? String ?? "Student"
                        let coachName = data["coachName"] as? String ?? "Coach"
                        let description = "\(studentName) booked a class with \(coachName)"
                        
                        transactions.append(FinanceTransaction(
                            id: document.documentID,
                            date: date,
                            description: description,
                            amount: amount,
                            type: .revenue,
                            relatedUserId: data["studentId"] as? String,
                            userName: studentName
                        ))
                    }
                }
                
                self.totalRevenue = revenue
                
                // Get coach payouts
                db.collection("coach_earnings")
                    .getDocuments { snapshot, error in
                        if let error = error {
                            print("Error loading coach earnings: \(error)")
                            return
                        }
                        
                        var payouts = 0
                        
                        for document in snapshot?.documents ?? [] {
                            let coachId = document.documentID
                            let data = document.data()
                            
                            if let earnings = data["totalEarnings"] as? Int {
                                payouts += earnings
                                
                                // Get coach name
                                db.collection("users").document(coachId).getDocument { snapshot, error in
                                    if let data = snapshot?.data(),
                                       let firstName = data["firstName"] as? String,
                                       let lastName = data["lastName"] as? String {
                                        
                                        let coachName = "\(firstName) \(lastName)"
                                        
                                        transactions.append(FinanceTransaction(
                                            id: UUID().uuidString,
                                            date: Date(), // Use current date as fallback
                                            description: "Earnings for \(coachName)",
                                            amount: earnings,
                                            type: .payout,
                                            relatedUserId: coachId,
                                            userName: coachName
                                        ))
                                    }
                                }
                            }
                        }
                        
                        self.coachPayouts = payouts
                        self.netRevenue = revenue - payouts
                        
                        // Generate monthly data
                        self.generateMonthlyRevenueData()
                        
                        // Filter transactions if needed
                        if let filter = filter {
                            self.recentTransactions = transactions
                                .filter { transaction in
                                    if let selectedType = filter.transactionType, 
                                       selectedType != transaction.type {
                                        return false
                                    }
                                    
                                    return true
                                }
                                .sorted(by: { $0.date > $1.date })
                                .prefix(10)
                                .map { $0 }
                        } else {
                            self.recentTransactions = transactions
                                .sorted(by: { $0.date > $1.date })
                                .prefix(10)
                                .map { $0 }
                        }
                        
                        self.isLoading = false
                    }
            }
    }
    
    private func generateMonthlyRevenueData() {
        let calendar = Calendar.current
        var monthlyData: [MonthlyRevenue] = []
        
        // Generate data for last 6 months
        for i in 0..<6 {
            let month = calendar.date(byAdding: .month, value: -i, to: Date())!
            let revenue = Int.random(in: 5000...20000) // Mock data - replace with actual calculations
            let expenses = Int.random(in: 2000...10000) // Mock data
            
            monthlyData.append(MonthlyRevenue(
                month: month,
                revenue: revenue,
                expenses: expenses
            ))
        }
        
        self.monthlyRevenueData = monthlyData.reversed() // Show oldest to newest
    }
}

struct FinanceCard: View {
    let title: String
    let amount: Int
    let icon: String
    let color: Color
    var fullWidth = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            Text("\(amount) credits")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding()
        .frame(maxWidth: fullWidth ? .infinity : nil)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct TransactionRow: View {
    let transaction: ManagerFinancesView.FinanceTransaction
    
    var body: some View {
        HStack {
            // Icon
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(amountText)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private var iconName: String {
        switch transaction.type {
        case .revenue:
            return "arrow.down.circle.fill"
        case .expense:
            return "arrow.up.circle.fill"
        case .payout:
            return "person.fill"
        }
    }
    
    private var color: Color {
        switch transaction.type {
        case .revenue:
            return .green
        case .expense, .payout:
            return .red
        }
    }
    
    private var backgroundColor: Color {
        switch transaction.type {
        case .revenue:
            return Color.green.opacity(0.2)
        case .expense, .payout:
            return Color.red.opacity(0.2)
        }
    }
    
    private var amountText: String {
        switch transaction.type {
        case .revenue:
            return "+\(transaction.amount)"
        case .expense, .payout:
            return "-\(transaction.amount)"
        }
    }
}

struct RevenueChart: View {
    let data: [ManagerFinancesView.MonthlyRevenue]
    
    var body: some View {
        Chart {
            ForEach(data) { item in
                BarMark(
                    x: .value("Month", item.monthString),
                    y: .value("Revenue", item.revenue)
                )
                .foregroundStyle(Color.green)
                
                BarMark(
                    x: .value("Month", item.monthString),
                    y: .value("Expenses", item.expenses)
                )
                .foregroundStyle(Color.red)
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned) { value in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel()
            }
        }
    }
}

struct TransactionFilter {
    var transactionType: ManagerFinancesView.FinanceTransaction.TransactionType?
    var startDate: Date?
    var endDate: Date?
}

struct TransactionFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: ManagerFinancesView.FinanceTransaction.TransactionType?
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var endDate = Date()
    
    let onApply: (TransactionFilter) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Transaction Type")) {
                    Button(action: { selectedType = nil }) {
                        HStack {
                            Text("All Types")
                            Spacer()
                            if selectedType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { selectedType = .revenue }) {
                        HStack {
                            Text("Revenue")
                            Spacer()
                            if selectedType == .revenue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    
                    Button(action: { selectedType = .payout }) {
                        HStack {
                            Text("Coach Payouts")
                            Spacer()
                            if selectedType == .payout {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section(header: Text("Date Range")) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                }
                
                Section {
                    Button("Apply Filter") {
                        let filter = TransactionFilter(
                            transactionType: selectedType,
                            startDate: startDate,
                            endDate: endDate
                        )
                        onApply(filter)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
                
                Section {
                    Button("Reset Filters") {
                        selectedType = nil
                        startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
                        endDate = Date()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filter Transactions")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct ManagerFinancesView_Previews: PreviewProvider {
    static var previews: some View {
        ManagerFinancesView()
    }
} 