import Foundation
import Testing
@testable import DatoCore

@Suite struct MeetingLinkDetectorTests {
    @Test func zoomWithPasswordGetsNativeURL() {
        let link = MeetingLinkDetector.detect(in: "Join: https://acme.zoom.us/j/123456789?pwd=abc123.")
        #expect(link?.provider == .zoom)
        #expect(link?.url.absoluteString == "https://acme.zoom.us/j/123456789?pwd=abc123")
        #expect(link?.nativeURL?.absoluteString == "zoommtg://acme.zoom.us/join?action=join&confno=123456789&pwd=abc123")
    }

    @Test func zoomPersonalLinkHasNoNativeURL() {
        let link = MeetingLinkDetector.detect(in: "https://acme.zoom.us/my/jane")
        #expect(link?.provider == .zoom)
        #expect(link?.nativeURL == nil)
    }

    @Test func googleMeet() {
        let link = MeetingLinkDetector.detect(in: "https://meet.google.com/abc-defg-hij?authuser=0")
        #expect(link?.provider == .googleMeet)
        #expect(link?.nativeURL == nil)
    }

    @Test func teamsGetsNativeURL() {
        let url = "https://teams.microsoft.com/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d"
        let link = MeetingLinkDetector.detect(in: "Click here \(url)")
        #expect(link?.provider == .teams)
        #expect(link?.nativeURL?.absoluteString == "msteams:/l/meetup-join/19%3ameeting_abc%40thread.v2/0?context=%7b%7d")
    }

    @Test func otherProviders() {
        #expect(MeetingLinkDetector.detect(in: "https://teams.live.com/meet/9876")?.provider == .teams)
        #expect(MeetingLinkDetector.detect(in: "https://acme.webex.com/meet/jane")?.provider == .webex)
        #expect(MeetingLinkDetector.detect(in: "https://facetime.apple.com/join#v=1&p=abc")?.provider == .facetime)
        #expect(MeetingLinkDetector.detect(in: "https://app.slack.com/huddle/T123/C456")?.provider == .slack)
    }

    @Test func ignoresOrdinaryLinks() {
        #expect(MeetingLinkDetector.detect(in: "Docs: https://docs.google.com/document/d/1") == nil)
    }

    @Test func findsAngleBracketedLinks() {
        #expect(MeetingLinkDetector.detect(in: "Meeting <https://meet.google.com/abc-defg-hij>")?.provider == .googleMeet)
    }

    @Test func urlFieldWinsThenLocationThenNotes() {
        let zoom = URL(string: "https://acme.zoom.us/j/1")!
        let teams = "https://teams.live.com/meet/1"
        let meet = "https://meet.google.com/abc-defg-hij"
        #expect(MeetingLinkDetector.detect(url: zoom, location: teams, notes: meet)?.provider == .zoom)
        #expect(MeetingLinkDetector.detect(url: nil, location: teams, notes: meet)?.provider == .teams)
        #expect(MeetingLinkDetector.detect(url: nil, location: "Room 4", notes: meet)?.provider == .googleMeet)
    }
}
