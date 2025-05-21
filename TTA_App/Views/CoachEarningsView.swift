import SwiftUI
import FirebaseFirestore
import FirebaseAuth

class EarningsViewModel: ObservableObject {
    @Published var currentMonthEarnings: Double = 0
    @Published var recentTransactions: [EarningTransaction] = []
    @Published var isLoading: Bool = true
    
    private let db = Firestore.firestore()
    
    func fetchEarningsData() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("User not authenticated")
            return
        }
        
        let bookingsRef = db.collection("bookings")
        let query = bookingsRef
            .whereField("coachId", isEqualTo: userId)
            .order(by: "bookedAt", descending: true)
            .limit(to: 10)
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching earnings data: \(error)")
                self.isLoading = false
                return
            }
            
            var transactions: [EarningTransaction] = []
            var currentMonthTotal: Double = 0
            
            // Get current month
            let now = Date()
            let calendar = Calendar.current
            
            snapshot?.documents.forEach { document in
                let data = document.data()
                let date = (data["bookedAt"] as? Timestamp)?.dateValue() ?? Date()
                let amount = data["cost"] as? Double ?? 0
                let costAsInt = Int(amount)  // Convert to Int for the model
                
                let transaction = EarningTransaction(
                    id: document.documentID,
                    amount: costAsInt,
                    timestamp: date,
                    studentId: data["studentId"] as? String ?? "",
                    coachId: userId,
                    classId: data["classId"] as? String,
                    classTime: data["classTime"] as? String,
                    description: data["description"] as? String ?? "Class Session"
                )
                
                transactions.append(transaction)
                
                // If transaction is in current month, add to monthly total
                if calendar.isDate(date, equalTo: now, toGranularity: .month) {
                    currentMonthTotal += amount
                }
            }
            
            DispatchQueue.main.async {
                self.recentTransactions = transactions
                self.currentMonthEarnings = currentMonthTotal
                self.isLoading = false
            }
        }
    }
}

struct CoachEarningsView: View {
    @StateObject private var viewModel = EarningsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Balance Card
                VStack(spacing: 8) {
                    Text("Total Earnings This Month")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("$\(viewModel.currentMonthEarnings, specifier: "%.2f")")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .padding(.horizontal)
                
                // Recent Transactions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Transactions")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView("Loading transactions...")
                            .padding()
                    } else if viewModel.recentTransactions.isEmpty {
                        Text("No recent transactions")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(viewModel.recentTransactions) { transaction in
                            EarningTransactionRow(transaction: transaction)
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            viewModel.fetchEarningsData()
        }
    }
}

struct EarningTransactionRow: View {
    let transaction: EarningTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(transaction.description ?? "Class Session")
                        .font(.headline)
                    Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                if transaction.amount == 0 {
                    Text("No Amount")
                        .font(.title3)
                        .bold()
                        .foregroundColor(.gray)
                } else {
                    Text("\(transaction.amount) credits")
                        .font(.title3)
                        .bold()
                }
            }
            
            if let classTime = transaction.classTime, !classTime.isEmpty {
                Text("Time: \(classTime)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CoachEarningsView_Previews: PreviewProvider {
    static var previews: some View {
        CoachEarningsView()
    }
} 
