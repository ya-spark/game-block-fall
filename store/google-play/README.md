# Google Play store assets (drafts)

- `listing.md` – title, short and full description (limits: 30 / 80 / 4000 chars).
- `privacy_policy.md` – draft; must be hosted at a public URL and linked in Play Console.
- `data_safety.md` – draft answers for the Data safety form.

Graphics (icon 512x512, feature graphic 1024x500, screenshots) are produced by the asset agent
and must be recorded in `assets/LICENSES.md` if they use third-party material.

## Store graphics kept in this repo (all generated for the Play listing)
- `graphics/icon-512.png`: the 512x512 store icon (same art as the app launcher icon).
- `graphics/feature-graphic-1024x500.png`: the feature graphic.
- `graphics/screenshots/phone-1-1080x2160.png` to `phone-3-1080x2160.png`: the three phone screenshots from the 1.1.0 look
  (Flutter web build rendered in Chromium at 360x720 at 3x). Regenerate after big visual changes.
- `graphics/alternates/`: an icon with an alpha channel and an alternate feature graphic.
- `graphics/screenshots/older/`: the two earlier screenshots.
