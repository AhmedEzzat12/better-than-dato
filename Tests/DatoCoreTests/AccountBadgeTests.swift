import Testing
@testable import DatoCore

@Suite struct AccountBadgeTests {
    @Test func emailUsesDomainInitial() {
        #expect(AccountBadge.defaultLabel(for: "jane@bluebird.com") == "B")
    }

    @Test func plainTitleUsesFirstLetter() {
        #expect(AccountBadge.defaultLabel(for: "iCloud") == "I")
    }

    @Test func skipsLeadingSymbols() {
        #expect(AccountBadge.defaultLabel(for: "  (Work)") == "W")
    }

    @Test func emptyTitleFallsBack() {
        #expect(AccountBadge.defaultLabel(for: "") == "?")
    }
}
