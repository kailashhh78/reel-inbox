// Command-line checks for Shared/InstagramLink.swift (run by .github/workflows/build.yml).
// Compiled with: swiftc Shared/InstagramLink.swift CI/ParserChecks/main.swift -o parser-checks
import Foundation

var failures = 0

func expect(_ input: String, _ expected: String?, kind: InstagramLink.Kind? = nil, line: Int = #line) {
    let link = InstagramLink.firstLink(in: input)
    let actual = link?.canonicalURL.absoluteString
    var ok = actual == expected
    if ok, let kind { ok = link?.kind == kind }
    if ok {
        print("PASS  \(input)")
    } else {
        failures += 1
        print("FAIL  (line \(line)) \(input)\n      expected \(expected ?? "nil") \(kind.map { "[\($0)]" } ?? ""), got \(actual ?? "nil") \(link.map { "[\($0.kind)]" } ?? "")")
    }
}

// Reels
expect("https://www.instagram.com/reel/C8xYz12AbCd/?igsh=MTc4MmM1YmI2Ng==", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("https://www.instagram.com/reel/C8xYz12AbCd", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("https://instagram.com/reels/C8xYz12AbCd/", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("http://m.instagram.com/reel/C8xYz12AbCd/", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("https://WWW.INSTAGRAM.COM/REEL/C8xYz12AbCd/", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("https://www.instagram.com/some.user_1/reel/C8xYz12AbCd/", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("https://www.instagram.com/reel/C8x-Yz_12Ab/#comments", "https://www.instagram.com/reel/C8x-Yz_12Ab/", kind: .reel)

// Posts / IGTV / share links
expect("https://www.instagram.com/p/ABCDE12345/?utm_source=ig_web_copy_link", "https://www.instagram.com/p/ABCDE12345/", kind: .post)
expect("https://www.instagram.com/someuser/p/ABCDE12345/", "https://www.instagram.com/p/ABCDE12345/", kind: .post)
expect("https://www.instagram.com/tv/ABCDE12345/", "https://www.instagram.com/tv/ABCDE12345/", kind: .igtv)
expect("https://www.instagram.com/share/reel/BAabc123XYZ", "https://www.instagram.com/share/reel/BAabc123XYZ/", kind: .shareLink)
expect("https://www.instagram.com/share/p/BAabc123XYZ/", "https://www.instagram.com/share/p/BAabc123XYZ/", kind: .shareLink)
expect("https://www.instagram.com/share/BAabc123XYZ/", "https://www.instagram.com/share/BAabc123XYZ/", kind: .shareLink)
expect("https://instagr.am/p/ABCDE12345/", "https://www.instagram.com/p/ABCDE12345/", kind: .post)

// Embedded in text, or without a scheme
expect("Look at this 😂 https://www.instagram.com/reel/C8xYz12AbCd/?igsh=abc lol", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("instagram.com/reel/C8xYz12AbCd", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)
expect("  \nhttps://www.instagram.com/reel/C8xYz12AbCd/\n", "https://www.instagram.com/reel/C8xYz12AbCd/", kind: .reel)

// Must be rejected
expect("https://www.instagram.com/reels/", nil)
expect("https://www.instagram.com/reels/audio/123456789/", nil)
expect("https://www.instagram.com/reels/audio", nil)
expect("https://www.instagram.com/explore/", nil)
expect("https://www.instagram.com/someuser/", nil)
expect("https://www.instagram.com/stories/someuser/3412345678901234567/", nil)
expect("https://www.instagram.com/reel/abc/", nil)               // too short
expect("https://www.instagram.com/reel/abc$%25def/", nil)        // invalid characters
expect("https://evil-instagram.com/reel/C8xYz12AbCd/", nil)
expect("https://www.instagram.com.evil.com/reel/C8xYz12AbCd/", nil)
expect("ftp://www.instagram.com/reel/C8xYz12AbCd/", nil)
expect("instagram://media?id=123", nil)
expect("https://www.youtube.com/shorts/abcdefghijk", nil)
expect("", nil)
expect("just some words", nil)

// Embed support
let reelLink = InstagramLink.firstLink(in: "https://www.instagram.com/reel/C8xYz12AbCd/")
let shareLink = InstagramLink.firstLink(in: "https://www.instagram.com/share/reel/BAabc123XYZ")
if reelLink?.supportsEmbed != true { failures += 1; print("FAIL  reel should support embed") }
if shareLink?.supportsEmbed != false { failures += 1; print("FAIL  share link should not support embed") }

print(failures == 0 ? "\nAll parser checks passed." : "\n\(failures) parser check(s) FAILED.")
exit(failures == 0 ? 0 : 1)
