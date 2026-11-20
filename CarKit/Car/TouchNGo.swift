import Foundation

/// One balance change, kept so a mistyped tap can be spotted.
public struct TnGChange: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var date: Date
    /// Signed change (top-ups positive, tolls negative). For "set balance" this is the difference.
    public var amount: Double
    public var balanceAfter: Double

    public init(id: UUID = UUID(), date: Date, amount: Double, balanceAfter: Double) {
        self.id = id
        self.date = date
        self.amount = amount
        self.balanceAfter = balanceAfter
    }
}

/// The manually tracked Touch 'n Go balance (`tng.json`). There is no TnG API.
public struct TnGState: Codable, Sendable, Equatable {
    public static let currentVersion = 1
    public static let defaultThreshold = 20.0
    public static let historyLimit = 50

    public var version: Int
    /// Nil until the first balance is entered.
    public var balance: Double?
    public var threshold: Double
    public var updatedAt: Date?
    public var history: [TnGChange]

    public init(
        version: Int = TnGState.currentVersion,
        balance: Double? = nil,
        threshold: Double = TnGState.defaultThreshold,
        updatedAt: Date? = nil,
        history: [TnGChange] = []
    ) {
        self.version = version
        self.balance = balance
        self.threshold = threshold
        self.updatedAt = updatedAt
        self.history = history
    }

    public static let empty = TnGState()

    /// Below the threshold means "Top up soon".
    public static func isLow(balance: Double, threshold: Double) -> Bool {
        balance < threshold
    }

    public var isLow: Bool {
        guard let balance else { return false }
        return Self.isLow(balance: balance, threshold: threshold)
    }

    /// Quick +/- button: adds a signed amount (rounded to sen).
    public mutating func apply(_ amount: Double, at date: Date) {
        setBalance((balance ?? 0) + amount, at: date)
    }

    /// Sets the exact balance read from the card or app.
    public mutating func setBalance(_ value: Double, at date: Date) {
        let rounded = (value * 100).rounded() / 100
        let change = rounded - (balance ?? 0)
        balance = rounded
        updatedAt = date
        history.insert(TnGChange(date: date, amount: (change * 100).rounded() / 100, balanceAfter: rounded), at: 0)
        if history.count > Self.historyLimit {
            history.removeLast(history.count - Self.historyLimit)
        }
    }
}
