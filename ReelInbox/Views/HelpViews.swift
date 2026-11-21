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
            Section("How Messages works") {
                Text("Instagram has no public API for a personal account's DMs. Meta shut down the Instagram Basic Display API on December 4, 2024. So the Messages tab shows Instagram's own website (instagram.com), limited to your chats. Reel Inbox blocks every other page, and hides the Home, Reels, Explore and Search buttons. If Instagram changes its website, an icon may reappear, but the pages behind it stay blocked.")
            }
            Section("Messages limits") {
                Text("No push notifications for new DMs: web pages can't send them to this app. Keep the Instagram app installed only for notifications, and limit it with Screen Time. Some features of the Instagram app may be missing on the website. Instagram may sometimes ask you to verify your login.")
            }
            Section("The Instagram app still has its feed") {
                Text("When a reel opens in the official Instagram app, Instagram controls that screen. Its viewer may let you swipe up to more recommended reels, and no other app can turn that off. To avoid it, pick \"Focused player\" in Settings, which shows only the one reel. Or swipe back to Reel Inbox right away using the \"◀ Reel Inbox\" button iOS shows in the top-left corner.")
            }
            Section("Sideloaded copies") {
                Text("If this app was installed with a sideloading tool and a free Apple ID, the App Group may be missing. Sharing then goes through the clipboard: open Reel Inbox right after sharing, before copying anything else.")
            }
            Section("Focused player limits") {
                Text("The focused player uses Instagram's official embed. Private accounts, age-restricted posts, and accounts that turned off embedding can't be shown there. Instagram may also show a \"View on Instagram\" card instead of playing the video. Use Open in Instagram for those reels.")
            }
            Section("No automatic previews by default") {
                Text("Link previews are off by default so the app doesn't contact Instagram in the background. When they're on, previews only work for public posts.")
            }
            Section("Block the real Instagram app") {
                Text("This app can't change the Instagram app itself. To keep its Reels tab out of reach: Settings > Screen Time > App Limits > Add Limit > Instagram, 1 minute a day, with Block at End of Limit on. Then have someone else set your Screen Time passcode.")
            }
            Section("What this app never does") {
                Text("Never sees or stores your Instagram password: you log in on Instagram's own page. No scraping, no private APIs, no feed, no autoplay, no recommendations, no notifications, no streaks.")
            }
        }
        .navigationTitle("Limitations")
        .navigationBarTitleDisplayMode(.inline)
    }
}
