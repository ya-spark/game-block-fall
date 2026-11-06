# Google Play store assets (drafts)

- `listing.md` – title, short and full description (limits: 30 / 80 / 4000 chars).
- `privacy_policy.md` – draft; must be hosted at a public URL and linked in Play Console.
- `data_safety.md` – draft answers for the Data safety form.
- `whatsnew/whatsnew-en-US` – the release notes (500 characters at most). The `release` workflow sends them to Play with every upload (`whatsNewDirectory`); edit before each release.

Graphics (icon 512x512, feature graphic 1024x500, screenshots) are produced by the asset agent
and must be recorded in `assets/LICENSES.md` if they use third-party material.

## Store graphics kept in this repo (all generated for the Play listing)
- `graphics/icon-512.png`: the 512x512 store icon (same art as the app launcher icon).
- `graphics/feature-graphic-1024x500.png`: the feature graphic.
- `graphics/screenshots/phone-*.png` (1080x2160): the phone screenshots of the **1.2.0** look (home, then play on the different themes),
  from a Flutter web build rendered in Chromium at 360x720 at 3x. Regenerate after big visual changes.
- `graphics/screenshots/older/1.1.0-look/`: the earlier 1.1.0 screenshots.
- `graphics/alternates/`: an icon with an alpha channel and an alternate feature graphic.
- `graphics/screenshots/older/`: the two earlier screenshots.
