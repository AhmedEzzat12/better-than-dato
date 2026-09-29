import Foundation

public enum AccountBadge {
    /// Default one-letter badge for an account. Email-style titles use the domain
    /// ("jane@bluebird.com" → "B") so two addresses starting with the same letter still differ.
    public static func defaultLabel(for accountTitle: String) -> String {
        let source = accountTitle.split(separator: "@").last.map(String.init) ?? accountTitle
        guard let first = source.first(where: { $0.isLetter || $0.isNumber }) else { return "?" }
        return String(first).uppercased()
    }
}
