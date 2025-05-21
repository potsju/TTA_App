import Foundation

struct CreditTransaction: Identifiable, Codable {
    let id: String
    let amount: Int
    let type: String
    let timestamp: Date
    let balance: Int
    let userId: String
}

// EarningTransaction moved to Transaction.swift for centralization 