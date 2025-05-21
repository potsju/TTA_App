import SwiftUI
import FirebaseFirestore
import Charts

struct BalanceView: View {
    @StateObject private var balanceService = BalanceService()
    @State private var showingAddMoney = false
    @State private var amount = ""
    @State private var transactionId = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var transactions: [CreditTransaction] = []
    @State private var isLoading = true
    @State private var showingMonthlyReport = false
    @State private var selectedMonth = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Balance Card
                            VStack(spacing: 8) {
                                Text("Current Balance")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("\(balanceService.balance) credits")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                            
                            // Action Buttons
                            HStack(spacing: 16) {
                                // Add Money Button
                                Button(action: {
                                    showingAddMoney = true
                                }) {
                                    VStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 24))
                                        Text("Add Credits")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(12)
                                }
                                
                                // Monthly Report Button
                                Button(action: {
                                    showingMonthlyReport = true
                                }) {
                                    VStack {
                                        Image(systemName: "chart.bar.fill")
                                            .font(.system(size: 24))
                                        Text("Monthly Report")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(TailwindColors.violet600)
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Monthly summary
                            MonthlySummaryView(transactions: transactions)
                            
                            // Transactions List
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Recent Transactions")
                                    .font(.system(size: 20, weight: .bold))
                                    .padding(.horizontal)
                                
                                ForEach(transactions) { transaction in
                                    TransactionRow2(transaction: transaction)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Balance")
            .sheet(isPresented: $showingAddMoney) {
                AddCreditsView(balanceService: balanceService)
            }
            .sheet(isPresented: $showingMonthlyReport) {
                MonthlyReportView(transactions: transactions)
            }
            .alert("Message", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        do {
            transactions = try await balanceService.getTransactionHistory()
        } catch {
            alertMessage = "Failed to load transactions: \(error.localizedDescription)"
            showAlert = true
        }
        
        isLoading = false
    }
}

struct TransactionRow2: View {
    let transaction: CreditTransaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.type)
                    .font(.system(size: 16, weight: .semibold))
                
                Text(transaction.timestamp, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(transaction.amount > 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(transaction.amount > 0 ? .green : .red)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct AddCreditsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var balanceService: BalanceService
    @State private var amount = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isAdding = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add Credits")) {
                    TextField("Amount", text: $amount)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: addCredits) {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add Credits")
                        }
                    }
                    .disabled(amount.isEmpty || isAdding)
                }
            }
            .navigationTitle("Add Credits")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert("Message", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func addCredits() {
        guard let amountInt = Int(amount), amountInt > 0 else {
            alertMessage = "Please enter a valid amount"
            showAlert = true
            return
        }
        
        isAdding = true
        
        Task {
            do {
                try await balanceService.addCredits(amount: amountInt)
                await MainActor.run {
                    isAdding = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to add credits: \(error.localizedDescription)"
                    showAlert = true
                    isAdding = false
                }
            }
        }
    }
}

struct MonthlySummaryView: View {
    let transactions: [CreditTransaction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Month")
                .font(.system(size: 18, weight: .bold))
            
            HStack(spacing: 24) {
                // Credits earned this month
                VStack {
                    Text("\(creditsEarnedThisMonth)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("Earned")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Credits spent this month
                VStack {
                    Text("\(creditsSpentThisMonth)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("Spent")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Net change
                VStack {
                    Text(netChangeThisMonth > 0 ? "+\(netChangeThisMonth)" : "\(netChangeThisMonth)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(netChangeThisMonth >= 0 ? .blue : .red)
                    
                    Text("Net")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal)
    }
    
    // Get transactions from this month only
    private var thisMonthTransactions: [CreditTransaction] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        return transactions.filter { transaction in
            return calendar.isDate(transaction.timestamp, inSameDayAs: startOfMonth) ||
                   calendar.isDate(transaction.timestamp, inSameDayAs: endOfMonth) ||
                   (transaction.timestamp > startOfMonth && transaction.timestamp < endOfMonth)
        }
    }
    
    // Credits earned this month (positive transactions)
    private var creditsEarnedThisMonth: Int {
        thisMonthTransactions
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Credits spent this month (negative transactions)
    private var creditsSpentThisMonth: Int {
        thisMonthTransactions
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    // Net change this month
    private var netChangeThisMonth: Int {
        thisMonthTransactions.reduce(0) { $0 + $1.amount }
    }
}

struct MonthlyReportView: View {
    let transactions: [CreditTransaction]
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @Environment(\.dismiss) var dismiss
    
    // Months in the year
    private let months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Year Picker
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text("\(year)").tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Monthly Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits by Month")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        if #available(iOS 16.0, *) {
                            Chart {
                                ForEach(monthlyData, id: \.month) { data in
                                    BarMark(
                                        x: .value("Month", data.month),
                                        y: .value("Earned", data.earned)
                                    )
                                    .foregroundStyle(.green)
                                    
                                    BarMark(
                                        x: .value("Month", data.month),
                                        y: .value("Spent", data.spent)
                                    )
                                    .foregroundStyle(.red)
                                }
                            }
                            .frame(height: 200)
                            .padding()
                        } else {
                            // Fallback for iOS 15 and earlier
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(monthlyData, id: \.month) { data in
                                    VStack(spacing: 4) {
                                        // Earned bar
                                        VStack {
                                            Spacer()
                                            Rectangle()
                                                .fill(Color.green)
                                                .frame(width: 20, height: CGFloat(data.earned) * 1.5)
                                        }
                                        .frame(height: 150)
                                        
                                        // Spent bar (negative value shown as positive height)
                                        VStack {
                                            Rectangle()
                                                .fill(Color.red)
                                                .frame(width: 20, height: CGFloat(data.spent) * 1.5)
                                            Spacer()
                                        }
                                        .frame(height: 50)
                                        
                                        // Month label
                                        Text(data.month.prefix(1))
                                            .font(.caption)
                                            .rotationEffect(.degrees(-45))
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Monthly Breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Monthly Breakdown")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        ForEach(monthlyData, id: \.month) { data in
                            if data.earned > 0 || data.spent > 0 {
                                HStack {
                                    Text(data.month)
                                        .font(.system(size: 16, weight: .medium))
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack {
                                            Text("Earned:")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            
                                            Text("\(data.earned)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.green)
                                        }
                                        
                                        HStack {
                                            Text("Spent:")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            
                                            Text("\(data.spent)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.red)
                                        }
                                        
                                        HStack {
                                            Text("Net:")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                            
                                            Text("\(data.earned - data.spent)")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(data.earned >= data.spent ? .blue : .red)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Annual Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Annual Summary for \(selectedYear)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        HStack(spacing: 24) {
                            // Credits earned this year
                            VStack {
                                Text("\(yearlyEarned)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.green)
                                
                                Text("Earned")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Credits spent this year
                            VStack {
                                Text("\(yearlySpent)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.red)
                                
                                Text("Spent")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // Net change
                            VStack {
                                Text(yearlyNet > 0 ? "+\(yearlyNet)" : "\(yearlyNet)")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(yearlyNet >= 0 ? .blue : .red)
                                
                                Text("Net")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Monthly Reports")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
        }
    }
    
    // Available years from transactions
    private var availableYears: [Int] {
        let years = Set(transactions.map { 
            Calendar.current.component(.year, from: $0.timestamp)
        }).sorted()
        
        // If no transactions, just show current year
        return years.isEmpty ? [Calendar.current.component(.year, from: Date())] : years
    }
    
    // Transactions for the selected year
    private var yearTransactions: [CreditTransaction] {
        transactions.filter { 
            Calendar.current.component(.year, from: $0.timestamp) == selectedYear
        }
    }
    
    // Credits earned this year
    private var yearlyEarned: Int {
        yearTransactions
            .filter { $0.amount > 0 }
            .reduce(0) { $0 + $1.amount }
    }
    
    // Credits spent this year
    private var yearlySpent: Int {
        yearTransactions
            .filter { $0.amount < 0 }
            .reduce(0) { $0 + abs($1.amount) }
    }
    
    // Net change for the year
    private var yearlyNet: Int {
        yearTransactions.reduce(0) { $0 + $1.amount }
    }
    
    // Data for monthly chart
    private var monthlyData: [(month: String, earned: Int, spent: Int)] {
        var data: [(month: String, earned: Int, spent: Int)] = []
        
        for (index, month) in months.enumerated() {
            let monthNumber = index + 1
            
            // Filter transactions for this month and year
            let monthTransactions = yearTransactions.filter {
                Calendar.current.component(.month, from: $0.timestamp) == monthNumber
            }
            
            // Calculate earned and spent
            let earned = monthTransactions
                .filter { $0.amount > 0 }
                .reduce(0) { $0 + $1.amount }
            
            let spent = monthTransactions
                .filter { $0.amount < 0 }
                .reduce(0) { $0 + abs($1.amount) }
            
            data.append((month: month, earned: earned, spent: spent))
        }
        
        return data
    }
}

struct BalanceView_Previews: PreviewProvider {
    static var previews: some View {
        BalanceView()
    }
} 
