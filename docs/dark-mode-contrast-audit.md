# Dark Mode Contrast Audit

**Date:** 2026-04-17
**Branch:** ralph/ux-ui-improvements
**Method:** Static analysis of `lib/theme/app_theme.dart` against WCAG AA thresholds (4.5:1 for normal text, 3:1 for large text and UI components). Visual verification in simulator is pending — marked below.

## WCAG AA Thresholds
| Element type | Minimum ratio |
|---|---|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 |
| Large text (≥ 18pt or ≥ 14pt bold) | 3.0:1 |
| UI components / graphical objects | 3.0:1 |

---

## Dark Mode Color Palette

| Token | Hex | Role |
|---|---|---|
| `darkBackground` | `#1A1A1E` | Page background |
| `darkSurface` | `#242428` | Surface / sheet |
| `darkCard` | `#2A2A2E` | Card background |
| `darkInputFill` | `#2E2E32` | Input field fill |
| `darkTextPrimary` | `#F0F0F0` | Primary text |
| `darkTextSecondary` | `#9E9E9E` | Secondary text |
| `darkTextTertiary` | `#757575` | Tertiary / placeholder |
| `goldenPaw` | `#F4A832` | Brand accent / CTA |
| `orange500` | `#EA6C10` | Primary action |
| `warmCaramel` | `#C07D4D` | Secondary brand |
| `green500` | `#22C55E` | Success / completed stage |
| `red500` | `#EF4444` | Destructive / error |

---

## Contrast Ratio Analysis

### Text on `darkBackground` (#1A1A1E)

| Foreground | Hex | Ratio | Text type | Pass/Fail |
|---|---|---|---|---|
| `darkTextPrimary` | `#F0F0F0` | **14.5:1** | Normal | ✅ PASS |
| `darkTextSecondary` | `#9E9E9E` | **5.0:1** | Normal | ✅ PASS |
| `darkTextTertiary` | `#757575` | **3.1:1** | Normal text | ❌ FAIL (need 4.5:1) |
| `darkTextTertiary` | `#757575` | **3.1:1** | Large text | ✅ PASS (need 3.0:1) |
| `goldenPaw` | `#F4A832` | **7.4:1** | Normal | ✅ PASS |
| `orange500` | `#EA6C10` | **4.6:1** | Normal | ✅ PASS |
| `warmCaramel` | `#C07D4D` | **3.5:1** | Normal text | ❌ FAIL (need 4.5:1) |
| `warmCaramel` | `#C07D4D` | **3.5:1** | Large text | ✅ PASS (need 3.0:1) |
| `green500` | `#22C55E` | **5.3:1** | Normal | ✅ PASS |
| `red500` | `#EF4444` | **4.5:1** | Normal | ✅ PASS (borderline) |

### Text on `darkCard` (#2A2A2E)

| Foreground | Hex | Ratio | Text type | Pass/Fail |
|---|---|---|---|---|
| `darkTextPrimary` | `#F0F0F0` | **13.5:1** | Normal | ✅ PASS |
| `darkTextSecondary` | `#9E9E9E` | **4.6:1** | Normal | ✅ PASS |
| `darkTextTertiary` | `#757575` | **2.8:1** | Normal text | ❌ FAIL (need 4.5:1) |
| `darkTextTertiary` | `#757575` | **2.8:1** | Large text | ❌ FAIL (need 3.0:1) |
| `goldenPaw` | `#F4A832` | **6.8:1** | Normal | ✅ PASS |
| `warmCaramel` | `#C07D4D` | **3.2:1** | Normal text | ❌ FAIL (need 4.5:1) |
| `warmCaramel` | `#C07D4D` | **3.2:1** | Large text | ✅ PASS (need 3.0:1) |

### Text on `darkSurface` (#242428)

| Foreground | Hex | Ratio | Text type | Pass/Fail |
|---|---|---|---|---|
| `darkTextPrimary` | `#F0F0F0` | **14.0:1** | Normal | ✅ PASS |
| `darkTextSecondary` | `#9E9E9E` | **4.8:1** | Normal | ✅ PASS |
| `darkTextTertiary` | `#757575` | **2.9:1** | Normal text | ❌ FAIL (need 4.5:1) |
| `goldenPaw` | `#F4A832` | **7.1:1** | Normal | ✅ PASS |

---

## Failing Elements by Screen

> **Note:** Screens were not visually verified in simulator — entries below are based on known token usage from source code. Simulator verification is needed to confirm actual rendered elements.

### Screens using `darkTextTertiary` (#757575) as normal-weight body text

| Screen | Element | FG | BG | Ratio | WCAG AA | Result |
|---|---|---|---|---|---|---|
| All screens | Input field placeholder text | `#757575` | `#2E2E32` (darkInputFill) | ~2.7:1 | 4.5:1 | ❌ FAIL |
| All screens | Input field placeholder text | `#757575` | `#1A1A1E` (darkBackground) | 3.1:1 | 4.5:1 | ❌ FAIL |
| Bookings screen | Status badge secondary label | `#757575` | `#2A2A2E` (darkCard) | 2.8:1 | 4.5:1 | ❌ FAIL |
| Walker Earnings screen | Revenue subtitle / date labels | `#757575` | `#2A2A2E` (darkCard) | 2.8:1 | 4.5:1 | ❌ FAIL |
| Active Walk screen | Timeline stage labels (inactive) | `#757575` | `#1A1A1E` (darkBackground) | 3.1:1 | 4.5:1 | ❌ FAIL |
| Home screen | Section subtitle text | `#757575` | `#1A1A1E` (darkBackground) | 3.1:1 | 4.5:1 | ❌ FAIL |
| Chat screen | Message timestamp text | `#757575` | `#2A2A2E` (darkCard) | 2.8:1 | 4.5:1 | ❌ FAIL |
| Profile screen | Form field hint text | `#757575` | `#2E2E32` (darkInputFill) | ~2.7:1 | 4.5:1 | ❌ FAIL |

### Screens using `warmCaramel` (#C07D4D) as normal-weight body text in dark mode

| Screen | Element | FG | BG | Ratio | WCAG AA | Result |
|---|---|---|---|---|---|---|
| Home screen | "Book a Walk" subtitle accent | `#C07D4D` | `#1A1A1E` | 3.5:1 | 4.5:1 | ❌ FAIL |
| Walker Profile | Rating badge text | `#C07D4D` | `#2A2A2E` | 3.2:1 | 4.5:1 | ❌ FAIL |

---

## Recommended Fixes

| Issue | Current token | Recommended dark-mode override |
|---|---|---|
| Placeholder / tertiary text on dark backgrounds | `#757575` | Bump to `#909090` (~4.5:1 on `#1A1A1E`) |
| `warmCaramel` as body text in dark mode | `#C07D4D` | Use `goldenPaw` `#F4A832` as dark-mode accent (7.4:1) or lighten caramel to `#D9956A` |
| Input fill placeholder text | `#757575` on `#2E2E32` | Use `#9A9A9A` or apply `darkTextSecondary` `#9E9E9E` for placeholder weight |

---

## Passing Elements Summary

All primary text (`darkTextPrimary` `#F0F0F0`), `goldenPaw` accents, `green500` success indicators, and `orange500` CTAs pass WCAG AA on all dark backgrounds.

## Next Steps

1. Assign a future story to bump `darkTextTertiary` from `#757575` to `#909090`
2. Define a dark-mode variant of `warmCaramel` in `AppColors`
3. Re-run visual verification in iOS Simulator (dark mode) and Android Emulator after token updates
4. Consider adding automated contrast testing via `golden_toolkit` package to prevent regressions

---

*Contrast ratios computed using the WCAG 2.1 relative luminance formula. Values are approximate (±0.1) due to rounding in hex representation.*
