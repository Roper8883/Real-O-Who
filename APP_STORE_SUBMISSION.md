# Real O Who App Store Submission Checklist

This project is set up as a private-sale property app for direct buyer and seller workflows, with the review-critical privacy and safety controls exposed in the native iOS and Android UIs.

## What is in the app

- Search-first property browsing with filters, featured listings, saved homes, and saved searches
- Private seller tools for listing management, owner market insight, and direct offers
- Inspection planner and market research surfaces inside listing detail
- Encrypted local buyer-seller messaging vault using device-held encryption keys
- In-app report and block controls for Secure Messages, plus abusive-language filtering on message and listing text
- In-app account deletion from the Account tab
- About screen with privacy, terms, support, and website links

## App Review positioning

- The app is reviewable without mandatory authentication. It launches directly into Browse with seeded launch users so a reviewer can run through all core flows on a clean device.
- If no backend is available, listings, conversations, legal workspace, reminders, and sale activity continue to work from local storage.
- Account deletion is available in-app at `Account > Data and privacy > Delete Account`.
- Secure Messages exposes `Report Conversation`, `Report Message`, and `Block User` from the thread menu and message context menu.
- Privacy Policy, Terms of Use, Support, Website, and support email are available from the Account tab and thread-level support menu.

## Public URLs

- Website: `https://roper8883.github.io/Real-O-Who/real-o-who/`
- Privacy Policy: `https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/`
- Terms of Use: `https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/`
- Support: `https://roper8883.github.io/Real-O-Who/real-o-who/support/`

## Suggested App Review Notes

`Real O Who` is a private-sale property app for buyers and sellers communicating directly. App Review can create a launch account in-app and test the core flow entirely on one device because the build falls back to local device storage when no backend is available.
The legal links used for App Store Connect are the updated docs in this repository and should be kept in sync before every submission.

For review access:
- No account creation is required for first-run review.
- Demo Buyer: `noah@realowho.app`
- Demo Seller: `mason@realowho.app`
- Demo Password: `HouseDeal123!`
- To test all user roles, open `Account` and use `Use Demo Buyer` / `Use Demo Seller`.
- Core messaging, offers, legal rep selection, and contract packet flows work in local mode without remote backend.

Review-critical controls:
- Account deletion is available at `Account > Data and privacy > Delete Account`.
- Secure Messages includes abusive-language filtering, `Report Conversation`, `Report Message`, and `Block User`.
- Support, privacy policy, terms, website, and support email are linked inside the app.

## Still required in App Store Connect

- Add final screenshots from the iPhone and iPad simulator
- Answer export compliance accurately. Apple’s current guidance says apps using encryption limited to Apple’s operating system don’t require extra documentation, but you should still confirm the questionnaire answers for this build.
- Confirm the support and privacy URLs are entered exactly as listed above
- Test once on a physical device before upload
- Keep the public website/privacy/support pages aligned with the current property marketplace product before shipping

## Apple guideline quick check (this build)

- Safety for communications: in-thread moderation, report, block, and support are all available and discoverable from within the conversation UI.
- Data handling: account/session, listing, messages, and legal workflow data persist in local storage with explicit account deletion and clear in-app support links.
- Review flow transparency: no authentication gate blocks onboarding.
- Content policy: no adult/inappropriate external content is intentionally included in seed data.

## Icon guideline verification (this build)

- Xcode is configured to use `AppIcon` via `ASSETCATALOG_COMPILER_APPICON_NAME` in both Debug and Release settings.
- The launch icon source is:
  - `Real O Who/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- The AppIcon asset has:
  - `1024x1024` dimensions
  - full opacity (no transparent pixels)
  - square, house-only composition
- In-app brand mark (used on screens) is now house-only at:
  - `Real O Who/Assets.xcassets/BrandMark.imageset/brand-mark-128.png`
  - `Real O Who/Assets.xcassets/BrandMark.imageset/brand-mark-256.png`
  - `Real O Who/Assets.xcassets/BrandMark.imageset/brand-mark-384.png`
- App Store Connect upload artifact to use:
  - `branding/generated/real-o-who-app-icon-1024.png`
- App Store Connect required uploads to include:
  - App Icon: PNG, 1024 x 1024, no alpha/transparency, square.
  - iPhone screenshots: currently prepared at `1242 x 2688` earlier for Store Connect.
  - iPad screenshots: prepare at current iPad device resolution requirement for each selected display size.
