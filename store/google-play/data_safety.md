# Data safety form - DRAFT answers (checked against the code on the listing stage)

Code facts this is based on: `google_mobile_ads` (AdMob + UMP consent), `in_app_purchase` (Play Billing),
`flutter_local_notifications` (local only), `shared_preferences` (local save). No Firebase, no own backend,
no analytics (AnalyticsService is a no-op), no account/login. Play Games is OFF in `app.config.yaml`
(`play_games.enabled: false`, no Play Games plugin); see the note at the end if it is enabled later.
Manifest permissions: INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, AD_ID.

| Question | Answer |
|----------|--------|
| Does the app collect or share user data? | Yes: collected and shared via the Google AdMob SDK only |
| Data types collected | Device or other IDs (Advertising ID). App activity / app interactions, Diagnostics (crash logs, performance) and approximate location (derived from IP) as collected automatically by the AdMob SDK |
| Data types NOT collected | Name, email, user IDs, precise location, contacts, photos, audio, files, health, financial info (payment is handled by Google Play), messages, web history |
| Purposes | Advertising or marketing; Analytics (AdMob ad measurement); Fraud prevention, security, compliance (AdMob) |
| Shared with third parties | Yes: Google AdMob (advertising ID, approximate location, ad interactions) |
| Is data processed ephemerally? | No |
| Collection required or optional? | Required for the free ad-supported experience; users in the EEA/UK/other regulated regions get a consent form (Google UMP), and can reopen it via "Ad privacy options" in Settings |
| Encrypted in transit? | Yes |
| Can users request deletion? | The developer holds no user data. Local data is removed by uninstalling or clearing app data; the advertising ID can be reset or deleted in Android settings |
| Purchases | Processed by Google Play Billing; the app never receives payment details |
| Notifications | Optional local reminder only; no push service, no data leaves the device |
| Follows Families Policy? | No. The app is not designed for children |

Play Console declarations:
- Contains ads: **Yes**
- Advertising ID declaration (Android 13+ `AD_ID` permission): **Yes**, used for advertising
- Target audience: 13+ (teen and general); not children
- App access: all functionality available without login

If Play Games Services is enabled later: also declare Device or other IDs (Play Games player ID) and
App activity (leaderboard score, achievements, saved game data), purpose App functionality, shared with Google Play Games. Update this file and the privacy policy first.
