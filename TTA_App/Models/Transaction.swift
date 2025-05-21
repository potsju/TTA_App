import Foundation

// DEPRECATED: This model is being phased out in favor of CreditTransaction
// Only kept for backward compatibility with existing code
struct Transaction: Identifiable, Codable {
    let id: String
    let amount: Double
    let type: TransactionType
    let date: Date
    let description: String
    let classTime: String?
    let transactionId: String
    
    enum TransactionType: String, Codable {
        case deposit
        case withdrawal
        case classPayment
    }
}

struct EarningTransaction: Identifiable, Codable {
    let id: String
    let amount: Int
    let timestamp: Date
    let studentId: String
    let coachId: String
    let classId: String?
    let classTime: String?
    let description: String?
    
    // Helper for displaying monetary values as Double
    var amountAsDouble: Double {
        return Double(amount)
    }
    
    // For compatibility with older code
    var date: Date { 
        return timestamp 
    }
    
    var status: String {
        return "completed"
    }
} 