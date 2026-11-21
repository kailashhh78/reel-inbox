import SwiftUI

struct HowToShareView: View {
    var body: some View {
        List {
            Section("From Instagram (recommended)") {
                step(1, "Open the reel your friend sent you in Instagram (for example from your DMs).")
                step(2, "Tap the Share (paper plane) button.")
                step(3, "Scroll the bottom row and tap Share to… (or More) to open the iOS share sheet.")
                step(4, "Choose Reel Inbox. If it's missing, tap More at the end of the app row and turn it on. You can also drag it to the front.")
                step(5, "Optionally type who sent it, then tap Save.")
            }
            Section("Copy and paste") {
                step(1, "In Instagram, tap Share, then Copy link.")
                step(2, "In Reel Inbox, tap + in the Inbox, then tap Paste.")
            }
            Section("From Messages, Safari, or anywhere else") {
                Text("Any app that shares an instagram.com link or text containing one works the same way: Share, then Reel Inbox.")
            }
        }
        .navigationTitle("How to add reels")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, alignment: .trailing)
            Text(text)
        }
    }
}

struct LimitationsView: View {
    var body: some View {
        List {
            Section("Instagram DMs can't be read automatically") {
                Text("Instagram has no public API that lets an app read a personal account's direct messages. Meta shut down the Instagram Basic Display API on December 4, 2024, and its messaging APIs are only for business and creator accounts. That's why you share reels into this app yourself.")
            }
            Section("The Instagram app still has its feed") {
                Text("When a reel opens in the official Instagram app, Instagram controls that screen. Its viewer may let you swipe up to more recommended reels, and no other app can turn that off. To avoid it, pick \"Focused player\" in Settings, which shows only the one reel. Or swipe back to Reel Inbox right away using the \"◀ Reel Inbox\" button iOS shows in the top-left corner.")
            }
            Section("Focused player limits") {
                Text("The focused player uses Instagram's official embed. Private accounts, age-restricted posts, and accounts that turned off embedding can't be shown there. Instagram may also show a \"View on Instagram\" card instead of playing the video. Use Open in Instagram for those reels.")
            }
            Section("No automatic previews by default") {
                Text("Link previews are off by default so the app doesn't contact Instagram in the background. When they're on, previews only work for public posts.")
            }
            Section("What this app never does") {
                Text("No Instagram login or password, no scraping, no private APIs, no feed, no autoplay, no recommendations, no notifications, no streaks.")
            }
        }
        .navigationTitle("Limitations")
        .navigationBarTitleDisplayMode(.inline)
    }
}
