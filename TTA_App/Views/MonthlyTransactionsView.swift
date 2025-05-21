import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DailyTransactionGroup: Identifiable {
    let id = UUID()
    let date: Date
    let transactions: [EarningTransaction]
    
    var dayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    var totalAmount: Int {
        transactions.reduce(0) { $0 + $1.amount }
    }
}

struct MonthlyTransactionsView: View {
    @State private var transactions: [EarningTransaction] = []
    @State private var groupedTransactions: [DailyTransactionGroup] = []
    @State private var isLoading = true
    @State private var selectedMonth = Date()
    @State private var availableMonths: [Date] = []
    @State private var monthOffset = 0
    private let monthsToShow = 24
    
    var body: some View {
        VStack(spacing: 0) {
            // Month selector
            VStack(spacing: 16) {
                // Remove or comment out the title since we now have a navigation title
                // Text("Monthly Transactions")
                //    .font(.title2)
                //    .fontWeight(.bold)
                //    .padding(.top)
                
                HStack {
                    Button(action: {
                        if monthOffset > 0 {
                            monthOffset -= 1
                            updateSelectedMonth()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(monthOffset > 0 ? .primary : .gray)
                            .padding(8)
                            .background(TailwindColors.violet50)
                            .cornerRadius(8)
                    }
                    .disabled(monthOffset <= 0)
                    
                    Spacer()
                    
                    Text(monthYearString(from: selectedMonth))
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        if monthOffset < availableMonths.count - 1 {
                            monthOffset += 1
                            updateSelectedMonth()
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(monthOffset < availableMonths.count - 1 ? .primary : .gray)
                            .padding(8)
                            .background(TailwindColors.violet50)
                            .cornerRadius(8)
                    }
                    .disabled(monthOffset >= availableMonths.count - 1)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<availableMonths.count, id: \.self) { index in
                            MonthButton(
                                month: availableMonths[index],
                                isSelected: index == monthOffset,
                                action: {
                                    withAnimation {
                                        monthOffset = index
                                        updateSelectedMonth()
                                    }
                                }
                            )
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
                            self.groupTransactionsByDay()
                        }
                    
                    Text("for \(monthYearString(from: selectedMonth))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("Tap 5 times to show sample data")
                        .font(.caption)
                        .foregroundColor(.gray.opacity(0.7))
                        .padding(.top, 4)
                }
                Spacer()
            } else {
                // Monthly summary card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly Summary")
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
                
                // Transactions list grouped by day
                List {
                    ForEach(groupedTransactions) { group in
                        Section(header: 
                            HStack {
                                Text(group.dayString)
                                Spacer()
                                Text("\(group.totalAmount) credits")
                                    .fontWeight(.semibold)
                                    .foregroundColor(TailwindColors.violet600)
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
        .navigationTitle("Monthly Transactions")
        .onAppear {
            generateAvailableMonths()
            fetchMonthlyTransactions()
        }
    }
    
    private func generateAvailableMonths() {
        let calendar = Calendar.current
        let currentDate = Date()
        
        var months: [Date] = []
        for i in 0..<monthsToShow {
            if let date = calendar.date(byAdding: .month, value: -i, to: currentDate) {
                // Get first day of month
                let components = calendar.dateComponents([.year, .month], from: date)
                if let firstDayOfMonth = calendar.date(from: components) {
                    months.append(firstDayOfMonth)
                }
            }
        }
        
        availableMonths = months
        selectedMonth = months[monthOffset]
    }
    
    private func updateSelectedMonth() {
        selectedMonth = availableMonths[monthOffset]
        fetchMonthlyTransactions()
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func groupTransactionsByDay() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.timestamp)
        }
        
        let groupedArray = grouped.map { (date, transactions) in
            DailyTransactionGroup(date: date, transactions: transactions.sorted(by: { $0.timestamp > $1.timestamp }))
        }
        
        groupedTransactions = groupedArray.sorted(by: { $0.date > $1.date })
    }

    private func fetchMonthlyTransactions() {
        isLoading = true
        transactions = [] // Reset transactions
        groupedTransactions = [] // Reset grouped transactions
        
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID available")
            isLoading = false
            return
        }
        
        print("DEBUG: Fetching monthly transactions for user \(userId)")
        print("DEBUG: Selected month: \(monthYearString(from: selectedMonth))")
        
        let db = Firestore.firestore()
        
        // First, try to get ANY transactions at all to verify the data exists
        db.collection("classes").getDocuments { snapshot, error in
            if let error = error {
                print("DEBUG: Error getting any classes: \(error)")
                return
            }
            
            let count = snapshot?.documents.count ?? 0
            print("DEBUG: Found \(count) total classes in the database")
            
            // Print details of first 5 classes to help debugging
            if count > 0 {
                let first5 = snapshot?.documents.prefix(5) ?? []
                print("DEBUG: First 5 classes details:")
                for (index, doc) in first5.enumerated() {
                    let data = doc.data()
                    print("DEBUG: Class \(index+1): ID=\(doc.documentID), data=\(data)")
                }
            }
        }
        
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
                
                // Process all classes and filter by month in memory
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
                
                // Filter by month in memory
                let calendar = Calendar.current
                let selectedYearMonth = calendar.dateComponents([.year, .month], from: self.selectedMonth)
                
                let filteredTransactions = allTransactions.filter { transaction in
                    let transactionYearMonth = calendar.dateComponents([.year, .month], from: transaction.timestamp)
                    return transactionYearMonth.year == selectedYearMonth.year && 
                           transactionYearMonth.month == selectedYearMonth.month
                }
                
                print("DEBUG: Filtered to \(filteredTransactions.count) transactions for \(self.monthYearString(from: self.selectedMonth))")
                
                // Update UI with transactions
                DispatchQueue.main.async {
                    self.transactions = filteredTransactions
                    
                    // If no transactions found, add mock data for testing
                    if filteredTransactions.isEmpty && UserDefaults.standard.bool(forKey: "showMockData") {
                        print("DEBUG: Adding mock data for testing")
                        self.addMockDataForTesting()
                    } else if filteredTransactions.isEmpty {
                        print("DEBUG: No transactions found for selected month. To show mock data, tap 5 times on 'No transactions found'")
                    }
                    
                    if !self.transactions.isEmpty {
                        self.groupTransactionsByDay()
                        print("DEBUG: Grouped into \(self.groupedTransactions.count) days")
                    }
                    
                    self.isLoading = false
                }
            }
    }
    
    private func addMockDataForTesting() {
        // Create mock data for current month
        let calendar = Calendar.current
        let daysInMonth = calendar.range(of: .day, in: .month, for: selectedMonth)?.count ?? 30
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // Create transactions for the current month
        var mockTransactions: [EarningTransaction] = []
        
        // Add 1-3 transactions for each day of the month
        for day in 1...min(daysInMonth, 28) {
            // Skip some days randomly
            if Int.random(in: 1...5) == 1 { continue }
            
            var dateComponents = calendar.dateComponents([.year, .month], from: selectedMonth)
            dateComponents.day = day
            
            if let date = calendar.date(from: dateComponents) {
                // Add 1-3 transactions per day
                let transactionsPerDay = Int.random(in: 1...3)
                
                for i in 1...transactionsPerDay {
                    let hourOffset = i * 2 // 2 hour gaps between classes
                    var timeComponents = calendar.dateComponents([.year, .month, .day], from: date)
                    timeComponents.hour = 9 + hourOffset // Start at 9 AM
                    
                    let transactionTime = calendar.date(from: timeComponents) ?? date
                    let timeString = formatter.string(from: transactionTime)
                    
                    let studentNames = ["Alex", "Jamie", "Morgan", "Taylor", "Jordan", "Casey", "Riley", "Quinn"]
                    let classTypes = ["Piano", "Guitar", "Violin", "Drums", "Voice", "Flute", "Saxophone", "Cello"]
                    
                    let studentName = studentNames.randomElement() ?? "Student"
                    let classType = classTypes.randomElement() ?? "Music"
                    let amount = Int.random(in: 5...15) * 10 // 50-150 credits
                    
                    let transaction = EarningTransaction(
                        id: UUID().uuidString,
                        amount: amount,
                        timestamp: transactionTime,
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

struct MonthButton: View {
    let month: Date
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(monthAbbreviation)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                
                Text(yearString)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? TailwindColors.violet100 : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? TailwindColors.violet400 : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var monthAbbreviation: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: month)
    }
    
    private var yearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: month)
    }
}
