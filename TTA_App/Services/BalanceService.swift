import Foundation
import FirebaseFirestore
import FirebaseAuth

class BalanceService: ObservableObject {
    @Published var balance: Int = 0
    private let db = Firestore.firestore()
    
    // Default starting credits for new students
    static let defaultStartingCredits = 100
    
    init() {
        Task {
            await loadBalance()
        }
    }
    
    func loadBalance() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user ID found for balance loading")
            return
        }
        
        do {
            // Get user document from Firestore
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let data = document.data(), let credits = data["credits"] as? Int {
                await MainActor.run {
                    self.balance = credits
                    print("DEBUG: Loaded balance from Firebase: \(self.balance)")
                }
            } else {
                // If no credits field, initialize it to default amount
                try await db.collection("users").document(userId).setData(["credits": BalanceService.defaultStartingCredits], merge: true)
                
                await MainActor.run {
                    self.balance = BalanceService.defaultStartingCredits
                    print("DEBUG: Initialized balance to \(BalanceService.defaultStartingCredits) credits in Firebase")
                }
            }
        } catch {
            print("DEBUG: Error loading balance from Firebase: \(error)")
        }
    }
    
    // Method to setup a new user with initial credits (called during account creation)
    static func setupNewUser(userId: String, isStudent: Bool) async {
        guard !userId.isEmpty else { return }
        
        let db = Firestore.firestore()
        
        do {
            // Check if the user document already exists
            let document = try await db.collection("users").document(userId).getDocument()
            
            // Only set default credits if the document exists but doesn't have credits field
            if document.exists {
                let data = document.data()
                if data?["credits"] == nil && isStudent {
                    // Set default credits for students only
                    try await db.collection("users").document(userId).setData(["credits": defaultStartingCredits], merge: true)
                    print("DEBUG: Set up new student with \(defaultStartingCredits) initial credits")
                }
            }
        } catch {
            print("DEBUG: Error setting up new user balance: \(error)")
        }
    }
    
    func addCredits(amount: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BalanceService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        // Get current balance from Firestore to ensure accuracy
        let document = try await db.collection("users").document(userId).getDocument()
        let currentBalance = document.data()?["credits"] as? Int ?? self.balance
        
        // Calculate new balance
        let newBalance = currentBalance + amount
        
        // Update in Firestore
        try await db.collection("users").document(userId).updateData([
            "credits": newBalance
        ])
        
        // Record transaction
        let transactionId = UUID().uuidString
        try await db.collection("credit_transactions").document(transactionId).setData([
            "id": transactionId,
            "userId": userId,
            "amount": amount,
            "type": "add",
            "timestamp": FieldValue.serverTimestamp(),
            "balance": newBalance
        ])
        
        // Update local state
        await MainActor.run {
            self.balance = newBalance
            print("DEBUG: Added \(amount) credits - New balance: \(self.balance)")
        }
    }
    
    func deductCredits(amount: Int) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BalanceService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        // Get current balance from Firestore to ensure accuracy
        let document = try await db.collection("users").document(userId).getDocument()
        let currentBalance = document.data()?["credits"] as? Int ?? self.balance
        
        // Check if there are enough credits
        guard currentBalance >= amount else {
            throw NSError(domain: "BalanceService", code: 101, userInfo: [NSLocalizedDescriptionKey: "Insufficient credits"])
        }
        
        // Calculate new balance
        let newBalance = currentBalance - amount
        
        // Update in Firestore
        try await db.collection("users").document(userId).updateData([
            "credits": newBalance
        ])
        
        // Record transaction
        let transactionId = UUID().uuidString
        try await db.collection("credit_transactions").document(transactionId).setData([
            "id": transactionId,
            "userId": userId,
            "amount": -amount,
            "type": "deduct",
            "timestamp": FieldValue.serverTimestamp(),
            "balance": newBalance
        ])
        
        // Update local state
        await MainActor.run {
            self.balance = newBalance
            print("DEBUG: Deducted \(amount) credits - New balance: \(self.balance)")
        }
    }
    
    func getTransactionHistory() async throws -> [CreditTransaction] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "BalanceService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        let snapshot = try await db.collection("credit_transactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { document -> CreditTransaction? in
            let data = document.data()
            guard let id = data["id"] as? String,
                  let amount = data["amount"] as? Int,
                  let type = data["type"] as? String,
                  let userId = data["userId"] as? String,
                  let balance = data["balance"] as? Int else {
                print("DEBUG: Failed to parse transaction document: \(data)")
                return nil
            }
            
            let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
            
            return CreditTransaction(
                id: id,
                amount: amount,
                type: type,
                timestamp: timestamp,
                balance: balance,
                userId: userId
            )
        }
    }
} 