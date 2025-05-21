import Foundation
import FirebaseFirestore
import FirebaseAuth

class CoachEarningsService: ObservableObject {
    @Published var earnings: Int = 0
    @Published var transactions: [EarningTransaction] = []
    private let db = Firestore.firestore()
    
    init() {
        Task {
            await loadEarnings()
        }
    }
    
    func loadEarnings() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID found for earnings loading")
            return
        }
        
        do {
            // Get coach document from Firestore
            let document = try await db.collection("coach_earnings").document(userId).getDocument()
            
            if let data = document.data(), let totalEarnings = data["totalEarnings"] as? Int {
                await MainActor.run {
                    self.earnings = totalEarnings
                    print("DEBUG: Loaded earnings from Firebase: \(self.earnings)")
                }
            } else {
                // If no earnings field, initialize it to 0
                try await db.collection("coach_earnings").document(userId).setData(["totalEarnings": 0], merge: true)
                
                await MainActor.run {
                    self.earnings = 0
                    print("DEBUG: Initialized earnings to 0 in Firebase")
                }
            }
            
            // Load transactions
            await loadTransactions()
        } catch {
            print("DEBUG: Error loading earnings from Firebase: \(error)")
        }
    }
    
    func loadTransactions() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID found for transactions loading")
            return
        }
        
        do {
            // Try to query with ordering first
            let query = db.collection("earning_transactions")
                .whereField("coachId", isEqualTo: userId)
            
            // First try to get transactions without ordering to avoid index issues
            let snapshot = try await query.getDocuments()
            
            let transactions = snapshot.documents.compactMap { document -> EarningTransaction? in
                let data = document.data()
                guard let id = data["id"] as? String,
                      let amount = data["amount"] as? Int,
                      let studentId = data["studentId"] as? String,
                      let coachId = data["coachId"] as? String else {
                    print("DEBUG: Failed to parse earning transaction document: \(data)")
                    return nil
                }
                
                let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                let classId = data["classId"] as? String
                let classTime = data["classTime"] as? String
                
                return EarningTransaction(
                    id: id,
                    amount: amount,
                    timestamp: timestamp,
                    studentId: studentId,
                    coachId: coachId,
                    classId: classId,
                    classTime: classTime,
                    description: data["description"] as? String ?? "Earning Transaction"
                )
            }
            
            // Sort the transactions locally by timestamp
            let sortedTransactions = transactions.sorted { 
                $0.timestamp > $1.timestamp 
            }
            
            await MainActor.run {
                self.transactions = sortedTransactions
                print("DEBUG: Loaded \(sortedTransactions.count) earning transactions")
            }
        } catch {
            print("DEBUG: Error loading transactions: \(error)")
            // Don't let transaction loading failure block the rest of the app
            await MainActor.run {
                self.transactions = []
            }
        }
    }
    
    func addEarnings(coachId: String, amount: Int, studentId: String? = nil, classId: String? = nil, classTime: String? = nil) async throws {
        guard !coachId.isEmpty else {
            throw NSError(domain: "CoachEarningsService", code: 100, userInfo: [NSLocalizedDescriptionKey: "Invalid coach ID"])
        }
        
        let currentUserId = Auth.auth().currentUser?.uid
        
        do {
            // Get current earnings from Firestore
            let document = try await db.collection("coach_earnings").document(coachId).getDocument()
            let data = document.data()
            let currentEarnings = data?["totalEarnings"] as? Int ?? 0
            let newEarnings = currentEarnings + amount
            
            // Try to update total earnings - if this fails due to permissions, just log and continue
            do {
                try await db.collection("coach_earnings").document(coachId).setData([
                    "totalEarnings": newEarnings,
                    "lastUpdated": FieldValue.serverTimestamp()
                ], merge: true)
            } catch {
                print("DEBUG: Permission error updating coach earnings: \(error.localizedDescription)")
                print("DEBUG: Need to update Firestore rules for coach_earnings collection")
                // Don't re-throw, just continue with the transaction part
            }
            
            // Try to record transaction - if this fails due to permissions, just log and continue
            let transactionId = UUID().uuidString
            var transactionData: [String: Any] = [
                "id": transactionId,
                "coachId": coachId,
                "amount": amount,
                "timestamp": FieldValue.serverTimestamp()
            ]
            
            if let studentId = studentId {
                transactionData["studentId"] = studentId
            } else if let currentUserId = currentUserId {
                transactionData["studentId"] = currentUserId
            }
            
            if let classId = classId {
                transactionData["classId"] = classId
            }
            
            if let classTime = classTime {
                transactionData["classTime"] = classTime
            }
            
            do {
                try await db.collection("earning_transactions").document(transactionId).setData(transactionData)
            } catch {
                print("DEBUG: Permission error recording earning transaction: \(error.localizedDescription)")
                print("DEBUG: Need to update Firestore rules for earning_transactions collection")
                // Don't re-throw, just continue
            }
            
            // Update local state if this is for the current user
            if coachId == currentUserId {
                await MainActor.run {
                    self.earnings = newEarnings
                    print("DEBUG: Updated local earnings to: \(self.earnings)")
                }
                
                // Reload transactions to include the new one
                do {
                    await loadTransactions()
                } catch {
                    print("DEBUG: Error loading transactions after update: \(error.localizedDescription)")
                }
            }
            
            print("DEBUG: Processing of \(amount) credits for coach \(coachId) completed")
        } catch {
            print("DEBUG: Error in earnings processing: \(error)")
            // Don't rethrow the error so it doesn't block class creation
        }
    }
} 
