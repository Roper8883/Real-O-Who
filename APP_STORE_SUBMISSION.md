# Real O Who App Store Submission Checklist

This project is now set up as a private property marketplace prototype for direct buyer and seller workflows.

## What is in the app

- Search-first property browsing with filters, featured listings, saved homes, and saved searches
- Private seller tools for listing management, owner market insight, and direct offers
- Inspection planner and market research surfaces inside listing detail
- Encrypted local buyer-seller messaging vault using device-held encryption keys
- About screen with privacy, terms, support, and website links

## Important product note

- This build is still a prototype. During development, the repo includes a lightweight local backend that can sync listings, account data, sale coordination, and conversations across devices.
- The shipped app still works without that backend because account, listing, and conversation state fall back to device storage when no service is available.
- A production launch would still need a hosted listing backend, account/identity verification, moderation, and a real encrypted transport service for multi-device messaging.

## Public URLs

- Website: `https://roper8883.github.io/Real-O-Who/real-o-who/`
- Privacy Policy: `https://roper8883.github.io/Real-O-Who/real-o-who/privacy-policy/`
- Terms of Use: `https://roper8883.github.io/Real-O-Who/real-o-who/terms-of-use/`
- Support: `https://roper8883.github.io/Real-O-Who/real-o-who/support/`

## Suggested App Review Notes

`Real O Who` is a private-sale property marketplace prototype. App Review can create a simple launch account or sign in to an account created on that same device. The build remains fully testable on one device because it falls back to local storage when no backend is available.

## Still required in App Store Connect

- Add final screenshots from the iPhone and iPad simulator
- Answer export compliance accurately. Apple’s current guidance says apps using encryption limited to Apple’s operating system don’t require extra documentation, but you should still confirm the questionnaire answers for this build.
- Confirm the support and privacy URLs are entered exactly as listed above
- Test once on a physical device before upload
- Align the public website/privacy/support pages with the current property marketplace product before shipping
