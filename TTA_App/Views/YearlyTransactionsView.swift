//
//  YearlyTransactionsView.swift
//  TTA_App
//
//  Created by Darren Choe on 4/8/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct MonthlyTransactionGroup: Identifiable {
    let id = UUID()
    let month: Date
    let transactions: [EarningTransaction]
    
    var monthString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: month)
    }
    
    var totalAmount: Int {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var transactionCount: Int {
        transactions.count
    }
}

struct YearlyTransactionsView: View {
    @State private var transactions: [EarningTransaction] = []
    @State private var groupedTransactions: [MonthlyTransactionGroup] = []
    @State private var isLoading = true
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var availableYears: [Int] = []
    
    private let yearsToShow = 7 // Current year plus 6 previous years
    
    var body: some View {
        VStack(spacing: 0) {
            // Year selector
            VStack(spacing: 16) {
                // Remove or comment out the title since we now have a navigation title
                // Text("Yearly Transactions")
                //    .font(.title2)
                //    .fontWeight(.bold)
                //    .padding(.top)
                
                // Scrollable years
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableYears, id: \.self) { year in
                            Button(action: {
                                withAnimation {
                                    selectedYear = year
                                    fetchYearlyTransactions()
                                }
                            }) {
                                Text("\(year)")
                                    .font(.headline)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(year == selectedYear ? TailwindColors.violet500 : TailwindColors.violet100)
                                    .foregroundColor(year == selectedYear ? .white : TailwindColors.violet700)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
            
            if isLoading {
                Spacer()
                ProgressView("Loading transactions...")
                Spacer()
            } else if transactions.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 50))
                        .foregroundColor(TailwindColors.violet300)
                    
                    Text("No transactions found")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .onTapGesture(count: 5) {
                            print("DEBUG: Enabling mock data after 5 taps")
                            UserDefaults.standard.set(true, forKey: "showMockData")
                            self.addMockDataForTesting()
                            self.groupTransactionsByMonth()
                        }
                    
                    Text("for \(selectedYear)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        
                    Text("Tap 5 times to show sample data")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 4)
                }
                Spacer()
            } else {
                // Yearly summary card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Yearly Summary")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Earnings")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("\(transactions.reduce(0) { $0 + $1.amount }) credits")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Total Bookings")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text("\(transactions.count)")
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Transactions list grouped by month
                List {
                    ForEach(groupedTransactions) { group in
                        Section(header: 
                            HStack {
                                Text(group.monthString)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(group.totalAmount) credits")
                                        .fontWeight(.semibold)
                                        .foregroundColor(TailwindColors.violet600)
                                    Text("\(group.transactionCount) bookings")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        ) {
                            ForEach(group.transactions) { transaction in
                                EarningTransactionRow(transaction: transaction)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Yearly Transactions")
        .onAppear {
            loadAvailableYears()
            fetchYearlyTransactions()
        }
    }
    
    private func loadAvailableYears() {
        let currentYear = Calendar.current.component(.year, from: Date())
        availableYears = (0..<yearsToShow).map { currentYear - $0 }
    }
    
    private func groupTransactionsByMonth() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            let components = calendar.dateComponents([.year, .month], from: transaction.timestamp)
            return calendar.date(from: components)!
        }
        
        let groupedArray = grouped.map { (date, transactions) in
            MonthlyTransactionGroup(
                month: date,
                transactions: transactions.sorted(by: { $0.timestamp > $1.timestamp })
            )
        }
        
        groupedTransactions = groupedArray.sorted(by: { $0.month > $1.month })
    }
    
    private func fetchYearlyTransactions() {
        isLoading = true
        transactions = [] // Reset transactions
        groupedTransactions = [] // Reset grouped transactions
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID available")
            isLoading = false
            return
        }
        
        print("DEBUG: Fetching yearly transactions for user \(userId)")
        print("DEBUG: Selected year: \(selectedYear)")
        
        let db = Firestore.firestore()
        
        // Now query classes specifically for this coach
        db.collection("classes")
            .whereField("coachId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("DEBUG: Error loading classes for coach: \(error)")
                    self.isLoading = false
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                print("DEBUG: Found \(count) classes for this coach")
                
                // Process all classes and filter by year in memory
                let allTransactions = snapshot?.documents.compactMap { document -> EarningTransaction? in
                    let data = document.data()
                    
                    // Try to get date from different possible fields
                    var dateValue: Date?
                    if let timestamp = data["date"] as? Timestamp {
                        dateValue = timestamp.dateValue()
                        print("DEBUG: Found date field in class \(document.documentID)")
                    } else if let timestamp = data["scheduledAt"] as? Timestamp {
                        dateValue = timestamp.dateValue()
                        print("DEBUG: Found scheduledAt field in class \(document.documentID)")
                    } else if let timestamp = data["bookedAt"] as? Timestamp {
                        dateValue = timestamp.dateValue()
                        print("DEBUG: Found bookedAt field in class \(document.documentID)")
                    } else {
                        print("DEBUG: No date field found in class \(document.documentID), data: \(data)")
                        // Use current date as fallback for testing
                        dateValue = Date()
                    }
                    
                    // For any class, return an EarningTransaction
                    let studentName = data["studentName"] as? String ?? "Student"
                    let className = data["className"] as? String ?? "Class"
                    let description = "\(className) with \(studentName)"
                    
                    // Try different field names for cost/credits
                    let amount: Double
                    if let cost = data["cost"] as? Double {
                        amount = cost
                    } else if let credits = data["credits"] as? Double {
                        amount = credits
                    } else if let costStr = data["cost"] as? String, let costDbl = Double(costStr) {
                        amount = costDbl
                    } else if let creditsStr = data["credits"] as? String, let creditsDbl = Double(creditsStr) {
                        amount = creditsDbl
                    } else if let costInt = data["cost"] as? Int {
                        amount = Double(costInt)
                    } else if let creditsInt = data["credits"] as? Int {
                        amount = Double(creditsInt)
                    } else {
                        // Default to 10 credits if no amount is specified
                        amount = 10
                    }
                    
                    return EarningTransaction(
                        id: document.documentID,
                        amount: Int(amount),
                        timestamp: dateValue ?? Date(),
                        studentId: data["studentId"] as? String ?? "",
                        coachId: userId,
                        classId: document.documentID,
                        classTime: data["classTime"] as? String ?? "",
                        description: description
                    )
                } ?? []
                
                // Filter by year in memory
                let calendar = Calendar.current
                
                let filteredTransactions = allTransactions.filter { transaction in
                    let year = calendar.component(.year, from: transaction.timestamp)
                    return year == self.selectedYear
                }
                
                print("DEBUG: Filtered to \(filteredTransactions.count) transactions for year \(self.selectedYear)")
                
                // Update UI with transactions
                DispatchQueue.main.async {
                    self.transactions = filteredTransactions
                    
                    // If no transactions found, add mock data for testing
                    if filteredTransactions.isEmpty && UserDefaults.standard.bool(forKey: "showMockData") {
                        print("DEBUG: Adding mock data for testing")
                        self.addMockDataForTesting()
                    } else if filteredTransactions.isEmpty {
                        print("DEBUG: No transactions found for selected year. To show mock data, tap 5 times on 'No transactions found'")
                    }
                    
                    if !self.transactions.isEmpty {
                        self.groupTransactionsByMonth()
                        print("DEBUG: Grouped into \(self.groupedTransactions.count) months")
                    }
                    
                    self.isLoading = false
                }
            }
    }
    
    private func addMockDataForTesting() {
        // Create mock data for the year
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Create transactions for each month
        var mockTransactions: [EarningTransaction] = []
        
        for month in 1...12 {
            // Create 5-15 transactions per month (more in recent months)
            let factor = month > 6 ? 2 : 1 // More transactions in later months
            let transactionsPerMonth = Int.random(in: 5...15) * factor
            
            for _ in 1...transactionsPerMonth {
                var dateComponents = DateComponents()
                dateComponents.year = selectedYear
                dateComponents.month = month
                dateComponents.day = Int.random(in: 1...28)
                dateComponents.hour = Int.random(in: 9...19)
                
                if let date = calendar.date(from: dateComponents) {
                    let timeString = formatter.string(from: date)
                    
                    let studentNames = ["Alex", "Jamie", "Morgan", "Taylor", "Jordan", "Casey", "Riley", "Quinn"]
                    let classTypes = ["Piano", "Guitar", "Violin", "Drums", "Voice", "Flute", "Saxophone", "Cello"]
                    
                    let studentName = studentNames.randomElement() ?? "Student"
                    let classType = classTypes.randomElement() ?? "Music"
                    let amount = Int.random(in: 5...15) * 10 // 50-150 credits
                    
                    let transaction = EarningTransaction(
                        id: UUID().uuidString,
                        amount: amount,
                        timestamp: date,
                        studentId: UUID().uuidString,
                        coachId: "mockCoachId",
                        classId: UUID().uuidString,
                        classTime: timeString,
                        description: "\(classType) Lesson with \(studentName)"
                    )
                    
                    mockTransactions.append(transaction)
                }
            }
        }
        
        if !mockTransactions.isEmpty {
            self.transactions = mockTransactions
        }
    }
}
