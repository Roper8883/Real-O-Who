# Real O Who

`Real O Who` is a private property marketplace prototype with native project infrastructure for iOS and Android. The current iOS app focuses on buyer search, saved listings, seller tools, direct offers, inspection planning, and encrypted local buyer-seller messaging for private sale workflows.

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

## Project Layout

- [Real O Who.xcodeproj](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/Real%20O%20Who.xcodeproj): iOS app project for Xcode
- [Real O Who](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/Real%20O%20Who): SwiftUI source for the private property marketplace app
- [android](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/android): Android Studio / Gradle project
- [docs/real-o-who](/Users/roper/Documents/Xcode%20Projects/Real%20O%20Who/docs/real-o-who): live support and legal website source
