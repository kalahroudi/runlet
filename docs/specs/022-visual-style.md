# Spec 022: Visual style

Status: In progress
Depends on: 001
Size estimate: M (about 350 lines including the bundled fonts as resources, excluding the font files)

## Why
The app works but looks like a developer placeholder: plain system text and default buttons. The approved mock (`docs/mock/runlet.html`) has a clear look: warm orange accent, rounded cards, soft borders, a display font for titles. Every later screen (quick-run popover 006, editor 005, preview 009) needs the same building blocks. This spec builds them once, applies them to what exists today, and leaves layouts to the specs that own them.

## Scope
- A small design kit in `Sources/RunLet/Style/` (plus `Sources/RunLetCore/Palette.swift` for the testable colour values): colour tokens, fonts, and a handful of SwiftUI components, matching the mock in light and dark.
- Apply the kit to the current popover (header, update banner, scratch box, footer), the main window placeholder, and the Settings window.
- Bundle the three fonts from the mock as app resources (Bricolage Grotesque, Instrument Sans, JetBrains Mono, all under the SIL Open Font License), with a system-font fallback.

## Non-goals
- The quick-run popover layout from the mock (search box, language chips, mini editor, recent snippets). That is spec 006.
- The editor and console (005), preview pane (009), agents card (012).
- A theme picker. The app follows the system light or dark appearance.
- Animations beyond a hover state.

## Behavior
### Tokens (from the mock)
| Token | Light | Dark |
|---|---|---|
| background | #EEF1F5 | #0E1116 |
| surface | #FFFFFF | #171B22 |
| surface 2 | #F6F8FB | #1D222B |
| line | #DDE2EA | #2B323E |
| ink | #14181F | #EDF0F5 |
| muted | #5F6B7E (mock: #667085, darkened to reach 4.5:1 on the page background) | #9AA4B5 |
| accent | #FF5B2E | #FF6B42 |
| accent soft | #FFE9E2 | #3A2018 |
| ok | #12A37A | #34D3A0 |
| code background | #FBFCFD | #12161C |

Radii: card 16 pt, control 9 pt, chip fully round. Borders are 1 pt in the line colour.

### Fonts
Titles use Bricolage Grotesque (700), body text Instrument Sans (400, 500, 600), code and console JetBrains Mono. Fonts are registered at launch from the app bundle. If one fails to load, the system font is used and nothing breaks.

### Components
- `RLButton`: secondary (surface, border) and primary (accent fill, white text), regular and small.
- `RLCard`: surface fill, line border, 16 pt radius, soft shadow in the popover.
- `RLChip`: small rounded label, optionally selected (ink fill).
- `RLSectionTitle`: 11 pt, uppercase, wide tracking, muted.
- `RLBanner`: accent-soft fill with an icon, used for the update notice.
- `RLStatusLine`: monospaced, `ok` colour for success, red for errors.

### Where it applies
- Popover: title in the display font, a card around the scratch box, primary Run button, footer strip on surface 2 with "Open in window" and the version. The update banner becomes `RLBanner`.
- Main window: surface background, title in the display font.
- Settings: card sections, `RLButton`s, mono version string.
- Scrolling areas hide the system scrollbar, as decided for spec 005.

## Acceptance criteria
- [ ] The popover, main window and Settings use the tokens above in both light and dark appearance, and switch live when the system appearance changes.
- [ ] Titles, body and code use the three bundled fonts, and the app still works if the font files are removed.
- [ ] Run is a primary button, other buttons are secondary, and all have a hover and a disabled state.
- [ ] The update banner uses `RLBanner` and appears only when an update is available.
- [x] Text contrast of ink and muted on surface is at least 4.5:1 in both appearances (checked with a script or tool and noted in the PR).
- [ ] A side-by-side screenshot of the popover and the mock is attached to the PR, and the product owner confirms it looks right.
- [ ] `swift test` and `./scripts/build.sh` pass in CI.

## Test plan
- Swift Testing tests for the token values (hex to colour) and the contrast helper in `RunLetCore`.
- Manual: light and dark checks, font fallback, screenshots against the mock.

## Risks and open questions
- Font files add size (a few hundred kB). Confirm that is acceptable, and keep only the weights used.
- `build.sh` copies resources by hand, so it must also copy the fonts and register them.
- A MenuBarExtra window cannot draw the mock's pointer arrow. The popover keeps the system chrome.
- The mock is scripted HTML, so exact spacing is approximate. The product owner's confirmation in the PR is the final check.
