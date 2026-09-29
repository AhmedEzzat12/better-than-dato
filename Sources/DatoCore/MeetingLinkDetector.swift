import Foundation

public enum MeetingProvider: String, CaseIterable, Hashable, Sendable {
    case zoom, googleMeet, teams, webex, facetime, slack

    public var displayName: String {
        switch self {
        case .zoom: "Zoom"
        case .googleMeet: "Google Meet"
        case .teams: "Microsoft Teams"
        case .webex: "Webex"
        case .facetime: "FaceTime"
        case .slack: "Slack Huddle"
        }
    }
}

public struct MeetingLink: Hashable, Sendable {
    public let provider: MeetingProvider
    public let url: URL
    /// Opens the provider's desktop app directly (Zoom, Teams); nil when there is none.
    public let nativeURL: URL?
}

public enum MeetingLinkDetector {
    /// Looks in the event URL, then location, then notes; the first meeting link wins.
    public static func detect(url: URL?, location: String?, notes: String?) -> MeetingLink? {
        if let url, let link = classify(url) { return link }
        for text in [location, notes].compactMap({ $0 }) {
            if let link = detect(in: text) { return link }
        }
        return nil
    }

    public static func detect(in text: String) -> MeetingLink? {
        guard let regex = try? NSRegularExpression(pattern: #"https?://[^\s<>"'\)\]]+"#) else { return nil }
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            var candidate = String(text[range])
            while let last = candidate.last, ".,;:!?".contains(last) { candidate.removeLast() }
            if let url = URL(string: candidate), let link = classify(url) { return link }
        }
        return nil
    }

    static func classify(_ url: URL) -> MeetingLink? {
        guard let host = url.host?.lowercased() else { return nil }
        let path = url.path

        if host == "zoom.us" || host.hasSuffix(".zoom.us"), ["/j/", "/my/", "/w/"].contains(where: path.hasPrefix) {
            return MeetingLink(provider: .zoom, url: url, nativeURL: zoomNativeURL(url, host: host))
        }
        if host == "meet.google.com", path.range(of: #"^/[a-z]{3}-[a-z]{4}-[a-z]{3}$"#, options: .regularExpression) != nil {
            return MeetingLink(provider: .googleMeet, url: url, nativeURL: nil)
        }
        if host == "teams.microsoft.com", path.hasPrefix("/l/meetup-join/") {
            return MeetingLink(provider: .teams, url: url, nativeURL: teamsNativeURL(url))
        }
        if host == "teams.live.com", path.hasPrefix("/meet/") {
            return MeetingLink(provider: .teams, url: url, nativeURL: nil)
        }
        if host.hasSuffix(".webex.com"), path.count > 1 {
            return MeetingLink(provider: .webex, url: url, nativeURL: nil)
        }
        if host == "facetime.apple.com", path.hasPrefix("/join") {
            return MeetingLink(provider: .facetime, url: url, nativeURL: nil)
        }
        if host == "app.slack.com", path.hasPrefix("/huddle/") {
            return MeetingLink(provider: .slack, url: url, nativeURL: nil)
        }
        return nil
    }

    /// https://acme.zoom.us/j/123?pwd=x → zoommtg://acme.zoom.us/join?action=join&confno=123&pwd=x
    static func zoomNativeURL(_ url: URL, host: String) -> URL? {
        guard url.path.hasPrefix("/j/") else { return nil }
        let meetingID = url.lastPathComponent
        guard !meetingID.isEmpty, meetingID.allSatisfy(\.isNumber) else { return nil }
        var components = URLComponents()
        components.scheme = "zoommtg"
        components.host = host
        components.path = "/join"
        var query = [URLQueryItem(name: "action", value: "join"), URLQueryItem(name: "confno", value: meetingID)]
        if let password = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "pwd" })?.value {
            query.append(URLQueryItem(name: "pwd", value: password))
        }
        components.queryItems = query
        return components.url
    }

    /// Keeps the original percent-encoding: msteams:/l/meetup-join/...?context=...
    static func teamsNativeURL(_ url: URL) -> URL? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let query = components.percentEncodedQuery.map { "?\($0)" } ?? ""
        return URL(string: "msteams:\(components.percentEncodedPath)\(query)")
    }
}
