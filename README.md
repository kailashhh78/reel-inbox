# Reel Inbox

A private, distraction-free iPhone companion for Instagram. Friends send you reels. You share each one into **Reel Inbox**, watch it on purpose, and come back to a finite list. There's no feed, no autoplay, no next reel, and no recommendations.

```
Instagram ──Share──▶ Share Extension ──JSON file in App Group──▶ Reel Inbox app ──SwiftData──▶ Inbox
                                                                     │
                                                       Watch ────────┴──▶ Instagram app / Focused player / Safari view
```

Swift, SwiftUI and SwiftData. iOS 18+, iPhone only, portrait. No backend, no account, no analytics, no third-party code.

---

## 1. What is and isn't possible (research summary)

| Question | Answer | Source |
|---|---|---|
| Can an app read my Instagram DMs? | **No.** Meta shut down the Instagram Basic Display API, the only consumer API, on **4 Dec 2024**. The remaining Instagram APIs are for business and creator accounts. | [Meta developer blog, 4 Sep 2024](https://developers.facebook.com/blog/post/2024/09/04/update-on-instagram-basic-display-api) |
| So how do reels get in? | The **iOS Share Sheet** (Instagram → Share → Reel Inbox), or copy link and paste. | — |
| Can the Watch button open the official Instagram app on that reel? | **Yes.** Through the reel's normal `https://www.instagram.com/reel/…` universal link. Instagram's `apple-app-site-association` file maps `/*` (including `/reel/*` and `/p/*`) to the Instagram app `com.burbn.instagram`. | `https://www.instagram.com/.well-known/apple-app-site-association` (fetched Nov 2026) |
| Can I stop Instagram from showing more reels after that one? | **No.** Once the Instagram app is open, Instagram controls the screen, and its viewer may let you swipe to more reels. No third-party app can change that. | — |
| Is there a supported way to show *only* one reel? | **Yes, for public posts.** Instagram's official **embed** (`blockquote.instagram-media` + `embed.js`). This is the "Focused player" option. It does not work for private accounts, age-restricted posts, or accounts that turned off embedding. | [Meta: Embed an Instagram Post](https://developers.facebook.com/docs/instagram-platform/oembed) |
| Do App Groups work with a **free** Apple Account (Personal Team)? | **Yes.** Apple's capability table marks "App groups" as available to the free "Apple Developer" tier. | [Apple: Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios) |
| Free-account limits | Apps expire **7 days** after install (re-run from Xcode). Up to **3 apps per device**. **10 App IDs per 7 days** (this project uses 2). | [Apple: Choosing a Membership](https://developer.apple.com/support/compare-memberships) |

### What the app does not do
No Instagram login or password. No scraping. No private or reverse-engineered APIs. No feed, Explore, trending, or recommendations. No infinite scroll. No autoplay. No notifications, badges, likes, or streaks. No cloud, no server, no analytics, no ads.

---

## 2. Features

- **Inbox** (home screen): unwatched links, newest first, as cards showing:
  - status (Unwatched / Watched) and type (Reel / Post)
  - sender ("From Alex", entered by you)
  - the link, plus an optional note
  - the date received
  - **Watch**, **Watched / Unwatched**, and **Delete** buttons
  - a ••• menu: Save, Edit sender & note, Copy link, Delete
  - swipe left to delete, swipe right to toggle watched
  - **+** to paste a link by hand. **Clear Inbox** deletes unwatched links but keeps Saved ones.
- **Saved**: links you chose to keep. They survive the inbox and watched clean-ups.
- **Watched**: history, with **Delete Watched**.
- **Settings**
  - **Open reels in**: *Instagram app* (default), *Focused player* (official embed, one reel only, links blocked), or *In-app browser* (Safari view).
  - **Mark as watched when opened** (on by default).
  - **Return to Inbox when I come back** (on by default). Returning from Instagram always lands on the Inbox.
  - **Show link previews** (off by default). Uses Apple's LinkPresentation to read the public title and thumbnail.
  - A Library count, plus **Erase All Data**.
  - **App Group self-test** (writes and deletes a probe file) and a count of links waiting to import.
  - Help and Limitations screens.
- **Share Extension** ("Reel Inbox" in the share sheet):
  - accepts a URL item or text that contains a link
  - validates the link and strips tracking parameters such as `igsh`
  - asks for an optional sender and note, then saves

**Recognized links:** `instagram.com/reel/{code}`, `/reels/{code}`, `/{user}/reel/{code}`, `/p/{code}`, `/{user}/p/{code}`, `/tv/{code}`, `/share/reel/{token}`, `/share/p/{token}` and `/share/{token}`, on `instagram.com`, `www.`, `m.` and `instagr.am`. The bare `/reels/` feed URL is rejected on purpose.

---

## 3. Requirements

- A Mac with **Xcode 16 or newer**. The project uses the Xcode 16 project format (objectVersion 77, folder-synchronized groups).
  - To install on an iPhone 17 running a current iOS, use the **current Xcode**. As of Nov 2026, Apple lists Xcode 27.x, which requires macOS Tahoe 26.6 or later ([Apple: Xcode system requirements](https://developer.apple.com/xcode/system-requirements)).
- An Apple Account signed into Xcode. Free is fine. A paid Developer Program membership removes the 7-day expiry.
- An iPhone 17 and a USB-C cable (or the same Wi-Fi network after first pairing).

---

## 4. Setup, step by step

### Step 1: Copy the project to your Mac
Copy the whole `ReelInbox` folder (the one containing `ReelInbox.xcodeproj`) to your Mac.

### Step 2: Set your own bundle IDs and App Group (one command)
Bundle IDs must be globally unique, so replace the placeholder `com.yourname`. In Terminal:

```bash
cd /path/to/ReelInbox
bash configure.sh com.yourname123     # use your own reverse-DNS prefix, e.g. com.janedoe
```

This rewrites the placeholder in exactly four files:

| File | What changes |
|---|---|
| `ReelInbox.xcodeproj/project.pbxproj` | App bundle ID `com.janedoe.reelinbox`, extension bundle ID `com.janedoe.reelinbox.share` |
| `Config/ReelInbox.entitlements` | App Group `group.com.janedoe.reelinbox` |
| `Config/ShareExtension.entitlements` | App Group `group.com.janedoe.reelinbox` |
| `Shared/AppGroup.swift` | `AppGroup.identifier = "group.com.janedoe.reelinbox"` |

> **Doing it by hand instead?** Change those same four places. The rules:
> - The extension's bundle ID **must start with** the app's bundle ID plus a dot.
> - The App Group string must be **identical** in both `.entitlements` files and in `AppGroup.swift`.

### Step 3: Open the project and set signing
1. Double-click `ReelInbox.xcodeproj`.
2. **Xcode → Settings → Accounts.** Add your Apple Account if it isn't there.
3. In the navigator, select the blue **ReelInbox** project, then select the **ReelInbox** target and open **Signing & Capabilities**:
   - Leave **Automatically manage signing** ticked.
   - **Team**: choose your team ("Your Name (Personal Team)" for a free account).
   - Check that **Bundle Identifier** shows your new ID.
   - Under **App Groups**, your `group.…reelinbox` should be listed and **ticked**. If it shows red, click the ↻ refresh button. If it's missing, click **+ Capability → App Groups**, then **+** and type the exact same ID.
4. Select the **ShareExtension** target and repeat: choose the **same Team** and check that the same App Group is ticked.
5. **Deployment target**: already set to **iOS 18.0** for the project and both targets (*Build Settings → iOS Deployment Target*). Leave it, or raise it if you like.

> If Xcode shows "Update to recommended settings", accepting is safe.

### Step 4: Prepare the iPhone (first time only)
1. Connect the iPhone 17 to the Mac with USB-C and tap **Trust** on the phone.
2. iPhone: **Settings → Privacy & Security → Developer Mode → On**, then restart when asked. The option appears after Xcode has seen the phone once.
3. In Xcode's toolbar, choose the scheme **ReelInbox** (not ShareExtension) and your iPhone as the run destination.

### Step 5: Build and run
Press **⌘R**.
- **Free account, first run:** iOS may block the app as an untrusted developer. On the iPhone go to **Settings → General → VPN & Device Management → your Apple ID → Trust**, then run again.
- With a free account the app stops launching after **7 days**. Connect the phone and press ⌘R again. Your saved links are kept.

### Step 6: Put "Reel Inbox" in the share sheet
1. Open Instagram, open any reel, and tap **Share** (paper plane).
2. Tap **Share to…** or **More** in the bottom row to open the iOS share sheet.
3. In the app row, scroll to the end and tap **More**. Turn on **Reel Inbox** and optionally drag it to *Favorites* so it's always first.

---

## 4b. No Mac? Cloud build + sideload from Windows

Every push to GitHub runs `.github/workflows/build.yml` on a GitHub-hosted Mac. It:
1. runs the link-parser checks (`CI/ParserChecks`)
2. compiles the app and the Share Extension for iOS devices, unsigned
3. checks the extension is embedded
4. uploads **`ReelInbox-unsigned-ipa`** as a downloadable file (an "artifact")

The bundle IDs in this repo are already set to `com.reelinboxq4hn4.reelinbox`, with App Group `group.com.reelinboxq4hn4.reelinbox`.

To install it on the iPhone from Windows:
1. Open the latest run under the repo's **Actions** tab, then download **ReelInbox-unsigned-ipa**. You must be signed in to GitHub. It downloads as a .zip containing the .ipa.
2. Install a Windows sideloading tool yourself, such as Sideloadly (from its official site). Sign in with your own Apple ID inside that tool. It signs the app with your free Apple account and installs it over USB.
3. On the iPhone, turn on **Settings → Privacy & Security → Developer Mode**. Then trust your Apple ID under **Settings → General → VPN & Device Management**.
4. The same free-account limits apply: re-install every 7 days.

**App Groups and sideloading:** the first Sideloadly install with a free Apple ID reported the App Group as *Not configured*. The app now handles this itself:
1. **Auto-detect.** At runtime the app and extension try the configured group, then any `ALTAppGroups` in Info.plist, then the groups in the app's `embedded.mobileprovision`. They use the first one iOS grants.
2. **Clipboard fallback.** If no group is available, the Share Extension puts the link (plus a private marker) on the clipboard. Reel Inbox imports it the next time it becomes active. iOS may ask **Allow Paste**. To stop that, set iOS **Settings → Apps → Reel Inbox → Paste from Other Apps → Allow**. Open Reel Inbox right after sharing, before copying anything else.

**Settings → Share Extension → App Group** shows **Working** (App Group in use) or **Using clipboard** (fallback).

---

## 5. Daily use

1. A friend sends you a reel in Instagram DMs.
2. Open it, tap **Share → Reel Inbox**, optionally type their name, tap **Save**. (Or close Instagram and watch it later.)
3. Open **Reel Inbox**. The link is in your Inbox. Tap **Watch**.
4. After watching:
   - *Instagram app mode:* tap **◀ Reel Inbox** in the iPhone's top-left corner (iOS shows this whenever one app opens another). You land on your Inbox.
   - *Focused player mode:* tap **Done**. There's nothing else to scroll.

**Tip:** for the least temptation, set **Settings → Open reels in → Focused player**. For reels that can't be embedded (private accounts, for example), the player shows an **Open in Instagram** button.

---

## 6. How it works (for maintenance)

```
ReelInbox/
├── ReelInbox.xcodeproj/        Xcode 16+ project (folder-synchronized groups: new files are picked up automatically)
├── ReelInbox/                  Main app target
│   ├── ReelInboxApp.swift      SwiftData container (local only: groupContainer .none, cloudKitDatabase .none)
│   ├── Models/Reel.swift       @Model: canonicalURL (unique), sender, note, dateReceived, isWatched, isSaved, preview
│   ├── Services/
│   │   ├── ShareImporter.swift   Imports queued shares → SwiftData. Deletes each file only after a successful save
│   │   ├── ReelRepository.swift  Insert or merge (dedupes by canonical URL), delete, bulk delete
│   │   ├── WatchRouter.swift     Watch button logic: universal link with .universalLinksOnly → Safari view fallback
│   │   ├── LinkPreviewService.swift  Optional LinkPresentation previews
│   │   └── AppSettings.swift
│   ├── Views/                  Inbox, Saved, Watched, Settings, ReelCard, AddReel, EditReel, FocusedPlayer, EmbedWebView, …
│   └── Assets.xcassets         AppIcon, AccentColor (#2563EB)
├── ShareExtension/             Share Extension target (UIViewController hosting SwiftUI)
├── Shared/                     Compiled into BOTH targets
│   ├── AppGroup.swift          App Group identifier
│   ├── InstagramLink.swift     URL validation and normalization
│   └── PendingShareStore.swift JSON-file queue in the App Group container
├── Config/                     Entitlements and the extension's Info.plist (not compiled; referenced by build settings)
└── configure.sh
```

**The handoff:**
1. The extension writes `AppGroup/PendingShares/<uuid>.json` with an atomic write.
2. When the app launches or returns to the foreground, it reads every file, inserts into SwiftData, saves, then deletes the file.
3. If the save fails, the file stays and is retried next time.

The SwiftData database is never opened by two processes at once.

**Watch, in Instagram mode:** `UIApplication.open(url, options: [.universalLinksOnly: true])`.
- If Instagram is installed and claims the link, iOS opens the Instagram app.
- If not, iOS reports failure and the app shows the link in an `SFSafariViewController` instead.

**Focused player:** a `WKWebView` that loads a local HTML page containing Meta's embed markup for one permalink. Restrictions:
- non-persistent data store (no cookies kept)
- media needs a tap to play
- main-frame navigation is blocked except for the local page
- link taps inside the embed and pop-ups (`window.open`, `target=_blank`) are blocked

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| Settings → Share Extension → App Group shows **Not configured** | The App Group isn't in the app's signed entitlements. Recheck Step 3 for **both** targets. The ID must match `Shared/AppGroup.swift` exactly. Then *Product → Clean Build Folder* (⇧⌘K) and run again. |
| The extension says Saved, but nothing appears in the Inbox | The extension and app use different App Group IDs, or the extension's group isn't ticked. Check Settings → **Waiting to import** and press **Import Shared Links Now**. |
| Reel Inbox isn't in the share sheet | Share sheet → scroll the app row → **More** → turn on Reel Inbox. Make sure you ran the **ReelInbox** scheme (it embeds the extension). Delete the app and run again if needed. |
| Watch opens Safari instead of Instagram | iOS remembers if you once chose "Open in Safari" for instagram.com links. Long-press any instagram.com link in Notes or Messages and choose **Open in "Instagram"** to reset it. Also check that Instagram is installed. |
| Focused player shows "View on Instagram" or an error | The post isn't embeddable (private, age-restricted, or embedding disabled), or Instagram changed its embed. Use **Open in Instagram**. |
| "Failed to register bundle identifier" | Someone else already uses that ID. Run `configure.sh` with a more unique prefix. (Run it on a fresh copy, or replace your previous prefix by hand.) |
| "Maximum number of apps for free development profiles" | Free accounts can have 3 sideloaded apps per device. Delete one of your other dev apps. |
| App won't launch after a week (free account) | Expected. Reconnect the phone and press ⌘R. |

---

## 8. Verification status

This project was written on a Windows machine without Xcode, so **it has not been compiled or run**. Every API used is public, and the code targets Swift 5 language mode to avoid strict-concurrency errors. Still, expect to possibly fix a small compile issue the first time.

**Untested, needs checking on your Mac and iPhone:**
1. The project file opens and both targets build (folder-synchronized groups, `Shared/` belongs to both targets).
2. Automatic signing registers the App Group for a Personal Team.
3. Instagram's share sheet lists Reel Inbox, and the extension receives the reel URL. Instagram may share it as a URL item or as text; both are handled.
4. Watch opens the Instagram app on the right reel.
5. Focused player actually plays reels. This depends on Meta's embed, which Meta may change.
6. Link previews, when enabled, return a thumbnail (Instagram may serve a login wall instead).

**Quick test checklist after the first install:**
- [ ] Settings → App Group shows **Working**.
- [ ] Inbox → **+** → paste `https://www.instagram.com/reel/<some code>/?igsh=abc` → the footer says "Detected reel" and **Add** works. The stored link has no `?igsh`.
- [ ] Paste `https://www.instagram.com/reels/` → it's rejected.
- [ ] Share a real reel from Instagram → Save → open Reel Inbox → the reel is in the Inbox with the sender you typed.
- [ ] Share the same reel again → no duplicate.
- [ ] Watch → Instagram opens that reel → ◀ Reel Inbox → you're on the Inbox and the reel is under Watched.
- [ ] Switch to Focused player → Watch → only that reel is shown, and links inside can't navigate away.
- [ ] Clear Inbox keeps Saved items. Erase All Data empties everything.

If anything fails to compile, paste the exact Xcode error and it can be fixed precisely.
