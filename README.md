# Real O Who

`Real O Who` is a private property marketplace prototype with native project infrastructure for iOS and Android. The apps include buyer search, saved listings, seller tools, direct offers, inspection planning, and buyer-seller messaging. In development, both platforms are now wired to a lightweight local backend so listings, auth, conversations, and sale coordination can sync across devices while still retaining local fallback storage when the backend is unavailable.

## Open In Xcode

Open [Real O Who.xcodeproj](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/Real%20O%20Who.xcodeproj) in Xcode, then run the `Real O Who` scheme on an iPhone or iPad simulator.

Command-line build:

```sh
xcodebuild -project "Real O Who.xcodeproj" -scheme "Real O Who" -destination 'generic/platform=iOS Simulator' build
```

## Open In Android Studio

Open the [android](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/android) folder in Android Studio. Android Studio will create `local.properties` automatically on first sync if it does not already exist.

Command-line build:

```sh
cd android
ANDROID_HOME="$HOME/Library/Android/sdk" ./gradlew assembleDebug
```

## Run The Local Backend

The repo now includes a lightweight development backend for shared listing inventory, account creation, sign in, saved homes, saved searches, conversation sync, legal-professional search, and sale coordination.

```sh
cd backend
npm start
```

It listens on `http://127.0.0.1:8080` for iOS Simulator and `http://10.0.2.2:8080` for the Android emulator. You can override the URL with `REAL_O_WHO_API_BASE_URL`.

### Seeded Demo Accounts

When the backend starts, it ensures these demo accounts exist:

- Buyer: `noah@realowho.app`
- Seller: `mason@realowho.app`
- Shared password: `HouseDeal123!`

Those demo users also share a seeded New Farm listing and sale so the browse, saved-state, legal-representative, contract, and direct-message workflow is ready to test.

## Project Layout

- [Real O Who.xcodeproj](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/Real%20O%20Who.xcodeproj): iOS app project for Xcode
- [Real O Who](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/Real%20O%20Who): SwiftUI source for the private property marketplace app
- [android](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/android): Android Studio / Gradle project
- [backend](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/backend): local development API for listings, auth, conversations, legal search, and shared sale sync
- [docs/real-o-who](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/docs/real-o-who): live support and legal website source

## Sync Status

- `iOS`: remote-first dev listings, saved homes, saved searches, auth, conversation sync, and sale coordination when the local backend is running, with local fallback when it is not
- `Android`: remote-first dev auth, sale coordination, and listing hydration when the local backend is running, with local fallback when it is not
- `Current limitation`: the included backend is a lightweight development server, not a production hosted service with identity verification, push notifications, or hardened multi-device encryption
