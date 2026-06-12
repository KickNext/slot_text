## 0.0.1

- Initial Flutter `SlotText` widget.
- Added declarative and imperative controller APIs.
- Added `set`, `flash`, `SlotTextOptions`, `SlotTextFlashOptions`, and `chromatic`.
- Added `startWaiting` with `SlotWaiting` idle presets: `ellipsis`, `wave`,
  `frames`, and `builder`, each with designed motion defaults and an
  auto-derived steady frame cadence.
- The stagger cascade now runs across changed slots only, so tail-only diffs
  (counters, ellipsis dots) start instantly; incoming glyphs skip `exitOffset`
  when their slot was empty.
- Added reduced-motion support: `SlotText` snaps instantly when the platform
  disables animations (`respectDisableAnimations`).
- Added widget tests and a two-page studio example app (designed showcase +
  developer recipes with live previews and copy-ready code).
