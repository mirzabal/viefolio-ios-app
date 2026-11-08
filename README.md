# Viefolio for iOS

The native iOS companion to **[viefolio.com](https://viefolio.com)**, a living portfolio platform. Every Viefolio user gets a public portfolio at `username.viefolio.com`; this app lets you manage it from your phone. Changes sync instantly to the web.

## Features

- **Projects:** create, edit, reorder and hide projects; track progress with checkpoints; attach images, links and tech stack. Status, type (solo, team, freelance, open source, academic…) and date ranges map directly to the public portfolio.
- **AI checkpoints:** Gemini suggests 5–8 milestones and their weightings from a project's title, description and tech stack.
- **Profile:** avatar, bio, skills with levels, social links, and per-section visibility for the public page.
- **Insights:** total / today / 7-day portfolio visits (Swift Charts) and the list of devices signed in to your account.
- **Home Screen widget:** visit stats via WidgetKit, fed through a shared App Group.
- **Account:** Sign in with Apple, Google, or email and password with code-based email verification; password change, session revocation and account deletion.
- **API access:** your UID and the read-only REST endpoint for pulling your portfolio data into your own sites.
- Light and dark mode in the Viefolio palette: brand green `#013E37`, cream `#FDFBF3`, butter `#FFEFB3`.

## Tech stack

| Layer | Tech |
| --- | --- |
| UI | SwiftUI, Observation (`@Observable`), Swift Charts, PhotosUI |
| Widget | WidgetKit + App Group (`group.com.mirzabal.viefolio`) |
| Auth | Firebase Auth: Apple, Google Sign-In, email/password |
| Data | Cloud Firestore (real-time listeners), Firebase Storage for images |
| AI | Google Generative AI SDK (Gemini) |
| Backend APIs | `viefolio.com/api/*` for password OTP and session revocation |

The app shares its Firebase project with the viefolio.com web app, so both read and write the same `profiles`, `projects`, `usernames` and `sessions` collections.

Requires **iOS 17+** and **Xcode 16+**. Dependencies are managed with Swift Package Manager.

## Project structure

```
Portfolio/
├── PortfolioApp.swift      App entry, Firebase setup, auth routing
├── ContentView.swift       Tab bar: Projects · Insights · Profile · Settings
├── Models/                 Profile, Project, Insights, Theme (palette + styles)
├── Services/               Auth, Firestore, Storage, Session, Gemini
└── Views/                  One file per screen
PortfolioWidget/            Home Screen visit widget
```

## Running locally

Secrets are not in the repo. To build your own copy:

1. Create a Firebase project with Auth (Apple, Google, Email), Firestore and Storage enabled.
2. Download its `GoogleService-Info.plist` into `Portfolio/`.
3. Update the Google URL scheme in `Portfolio/Info.plist` to your `REVERSED_CLIENT_ID`.
4. Optional, for AI checkpoints: create `Portfolio/Secrets.plist` with a `GEMINI_API_KEY` string.
5. Open `Portfolio.xcodeproj`, set your signing team and bundle IDs, then run.

`GoogleService-Info.plist` and `Secrets.plist` are gitignored and must never be committed.

## Links

- Website: [viefolio.com](https://viefolio.com)
- [Terms of Service](https://viefolio.com/terms) · [Privacy Policy](https://viefolio.com/privacy)
