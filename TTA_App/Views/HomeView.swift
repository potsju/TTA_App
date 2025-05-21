import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct TransactionSummary: Identifiable {
    let id = UUID()
    let title: String
    let amount: Int
    let count: Int
    let timePeriod: String
}

struct HomeView: View {
    @State private var currentMonthTransactions: [EarningTransaction] = []
    @State private var currentYearTransactions: [EarningTransaction] = []
    @State private var isLoading = true
    @State private var userName: String = "Coach"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text(userName)
                                .font(.system(size: 24, weight: .bold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView("Loading transaction data...")
                            .padding()
                    } else {
                        // Summary cards
                        VStack(spacing: 16) {
                            // Current month summary
                            SummaryCard(
                                title: "This Month",
                                amount: currentMonthTransactions.reduce(0) { $0 + $1.amount },
                                count: currentMonthTransactions.count,
                                color: TailwindColors.violet500
                            )
                            
                            // Current year summary
                            SummaryCard(
                                title: "This Year",
                                amount: currentYearTransactions.reduce(0) { $0 + $1.amount },
                                count: currentYearTransactions.count,
                                color: TailwindColors.green500
                            )
                        }
                        .padding(.horizontal)
                        
                        // Transaction reports buttons
                        HStack(spacing: 12) {
                            NavigationLink {
                                MonthlyTransactionsView()
                            } label: {
                                ReportButton(
                                    title: "Monthly Report",
                                    icon: "calendar",
                                    color: TailwindColors.violet600
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            NavigationLink {
                                YearlyTransactionsView()
                            } label: {
                                ReportButton(
                                    title: "Yearly Report",
                                    icon: "chart.bar.fill",
                                    color: TailwindColors.green600
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        // Recent transactions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if currentMonthTransactions.isEmpty {
                                Text("No recent transactions")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(Array(currentMonthTransactions.prefix(5))) { transaction in
                                    Button(action: {
                                        // In the future, we could add transaction detail view navigation here
                                        print("Transaction tapped: \(transaction.id)")
                                    }) {
                                        EarningTransactionRow(transaction: transaction)
                                            .background(Color(.systemBackground))
                                            .cornerRadius(8)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all))
            .onAppear {
                loadUserName()
                loadTransactionSummaries()
            }
            .refreshable {
                loadTransactionSummaries()
            }
        }
    }
    
    private func loadUserName() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error loading user: \(error)")
                return
            }
            
            if let data = snapshot?.data(),
               let name = data["name"] as? String {
                self.userName = name
            }
        }
    }
    
    private func loadTransactionSummaries() {
        isLoading = true
        
        let group = DispatchGroup()
        
        group.enter()
        fetchCurrentMonthTransactions { transactions in
            self.currentMonthTransactions = transactions
            group.leave()
        }
        
        group.enter()
        fetchCurrentYearTransactions { transactions in
            self.currentYearTransactions = transactions
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    private func fetchCurrentMonthTransactions(completion: @escaping ([EarningTransaction]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        var allTransactions: [EarningTransaction] = []
        let group = DispatchGroup()
        
        // Query classes collection
        group.enter()
        db.collection("classes")
            .whereField("coachId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("DEBUG: Error loading classes: \(error)")
                    return
                }
                
                let transactions = snapshot?.documents.compactMap { document -> EarningTransaction? in
                    let data = document.data()
                    
                    // Try to get date from different possible fields
                    var date: Date?
                    if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["scheduledAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["bookedAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    }
                    
                    // Skip if date is missing or outside selected month
                    guard let validDate = date else { return nil }
                    
                    let dateComponents = calendar.dateComponents([.year, .month], from: validDate)
                    let currentComponents = calendar.dateComponents([.year, .month], from: Date())
                    
                    guard dateComponents.year == currentComponents.year && 
                          dateComponents.month == currentComponents.month else {
                        return nil
                    }
                    
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
                        timestamp: validDate,
                        studentId: data["studentId"] as? String ?? "",
                        coachId: userId,
                        classId: document.documentID,
                        classTime: data["classTime"] as? String ?? "",
                        description: description
                    )
                } ?? []
                
                allTransactions.append(contentsOf: transactions)
            }
        
        // Also check completedClasses collection
        group.enter()
        db.collection("completedClasses")
            .whereField("coachId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("DEBUG: Error loading completed classes: \(error)")
                    return
                }
                
                let transactions = snapshot?.documents.compactMap { document -> EarningTransaction? in
                    let data = document.data()
                    
                    // Try to get date from different possible fields
                    var date: Date?
                    if let timestamp = data["completedAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["scheduledAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    }
                    
                    // Skip if date is missing or outside selected month
                    guard let validDate = date else { return nil }
                    
                    let dateComponents = calendar.dateComponents([.year, .month], from: validDate)
                    let currentComponents = calendar.dateComponents([.year, .month], from: Date())
                    
                    guard dateComponents.year == currentComponents.year && 
                          dateComponents.month == currentComponents.month else {
                        return nil
                    }
                    
                    let studentName = data["studentName"] as? String ?? "Student"
                    let className = data["className"] as? String ?? "Completed Class"
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
                        timestamp: validDate,
                        studentId: data["studentId"] as? String ?? "",
                        coachId: userId,
                        classId: document.documentID,
                        classTime: data["classTime"] as? String ?? "",
                        description: description
                    )
                } ?? []
                
                allTransactions.append(contentsOf: transactions)
            }
        
        // When all queries are done, update the transactions
        group.notify(queue: .main) {
            // Remove duplicates and sort by date
            let uniqueTransactions = Dictionary(grouping: allTransactions, by: { $0.id })
                .compactMap { $0.value.first }
                .sorted(by: { $0.timestamp > $1.timestamp })
            
            completion(uniqueTransactions)
        }
    }
    
    private func fetchCurrentYearTransactions(completion: @escaping ([EarningTransaction]) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion([])
            return
        }
        
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var allTransactions: [EarningTransaction] = []
        let group = DispatchGroup()
        
        // Query classes collection
        group.enter()
        db.collection("classes")
            .whereField("coachId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("DEBUG: Error loading classes: \(error)")
                    return
                }
                
                let transactions = snapshot?.documents.compactMap { document -> EarningTransaction? in
                    let data = document.data()
                    
                    // Try to get date from different possible fields
                    var date: Date?
                    if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["scheduledAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["bookedAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    }
                    
                    // Skip if date is missing or outside current year
                    guard let validDate = date else { return nil }
                    
                    let dateYear = calendar.component(.year, from: validDate)
                    guard dateYear == currentYear else { return nil }
                    
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
                        timestamp: validDate,
                        studentId: data["studentId"] as? String ?? "",
                        coachId: userId,
                        classId: document.documentID,
                        classTime: data["classTime"] as? String ?? "",
                        description: description
                    )
                } ?? []
                
                allTransactions.append(contentsOf: transactions)
            }
        
        // Also check completedClasses collection
        group.enter()
        db.collection("completedClasses")
            .whereField("coachId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("DEBUG: Error loading completed classes: \(error)")
                    return
                }
                
                let transactions = snapshot?.documents.compactMap { document -> EarningTransaction? in
                    let data = document.data()
                    
                    // Try to get date from different possible fields
                    var date: Date?
                    if let timestamp = data["completedAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["date"] as? Timestamp {
                        date = timestamp.dateValue()
                    } else if let timestamp = data["scheduledAt"] as? Timestamp {
                        date = timestamp.dateValue()
                    }
                    
                    // Skip if date is missing or outside current year
                    guard let validDate = date else { return nil }
                    
                    let dateYear = calendar.component(.year, from: validDate)
                    guard dateYear == currentYear else { return nil }
                    
                    let studentName = data["studentName"] as? String ?? "Student"
                    let className = data["className"] as? String ?? "Completed Class"
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
                        timestamp: validDate,
                        studentId: data["studentId"] as? String ?? "",
                        coachId: userId,
                        classId: document.documentID,
                        classTime: data["classTime"] as? String ?? "",
                        description: description
                    )
                } ?? []
                
                allTransactions.append(contentsOf: transactions)
            }
        
        // When all queries are done, update the transactions
        group.notify(queue: .main) {
            // Remove duplicates and sort by date
            let uniqueTransactions = Dictionary(grouping: allTransactions, by: { $0.id })
                .compactMap { $0.value.first }
                .sorted(by: { $0.timestamp > $1.timestamp })
            
            completion(uniqueTransactions)
        }
    }
}

struct SummaryCard: View {
    let title: String
    let amount: Int
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Earnings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(amount) credits")
                        .font(.title3)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Bookings")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("\(count)")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            Rectangle()
                .fill(color)
                .frame(width: 4)
                .cornerRadius(4)
                .padding(.vertical, 8),
            alignment: .leading
        )
    }
}

struct ReportButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
            Text(title)
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color)
        .cornerRadius(10)
    }
}

#if compiler(>=5.9)
#Preview {
    HomeView()
}
#else
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
#endif 