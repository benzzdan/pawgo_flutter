# Rate Your Walk — Design Spec

**Date:** 2026-04-15  
**Status:** Approved

## Overview

When a walker ends a walk, the dog owner is prompted to rate the walk. The prompt slides up as a bottom sheet. The owner can submit a rating (1–5 stars, optional comment) or skip. After either action they land on My Bookings. The walker is sent to their Upcoming tab, not the review screen.

---

## Components

### 1. `ReviewBottomSheet` widget — `lib/widgets/review_bottom_sheet.dart` (new)

Extract the review form from `ReviewScreen` into a standalone widget. Same UI as the existing screen:

- Walker avatar (orange gradient icon)
- "How was your walk with [walker_name]?"
- 5-star tap rating with label (Poor / Fair / Good / Great / Excellent!)
- Optional comment field (max 500 chars)
- "Submit Review" button (orange, full width)
- "Skip for now" text button

Called via `showModalBottomSheet` with `isScrollControlled: true`. Accepts:
- `bookingId: String`
- `walkerId: String`
- `walkerName: String`

On **submit**: inserts into `reviews` table, fires `AnalyticsService.reviewSubmitted`, closes the sheet, then caller navigates to My Bookings (past tab).  
On **skip**: closes the sheet, caller navigates to My Bookings (past tab).  
On **duplicate error**: shows snackbar "You have already reviewed this walk", closes sheet.

### 2. `ReviewScreen` — `lib/screens/review_screen.dart` (unchanged)

Kept as-is. The `/review` named route remains registered. It is no longer navigated to from `active_walk_screen`, but is retained for potential future use.

### 3. `end-walk` Edge Function — `Pawgo-api/supabase/functions/end-walk/index.ts` (modified)

Enriches the existing FCM push notification sent to the owner with review prompt fields:

```json
{
  "title": "Walk complete! ⭐",
  "body": "How was your walk with {walker_name}? Tap to rate.",
  "data": {
    "review_prompt": "true",
    "booking_id": "<booking_id>",
    "walker_id": "<walker_id>",
    "walker_name": "<walker_name>"
  }
}
```

No new migrations, tables, or RLS policies required. The `reviews` table and `update_walker_rating` trigger already exist.

---

## Navigation Changes — `active_walk_screen.dart`

The Realtime callback that fires when `booking.status` becomes `walk_completed` (currently line ~386) is split by role:

**Walker (`_isWalker == true`):**
```dart
Navigator.pushReplacementNamed(
  context, '/walker-bookings',
  arguments: {'initialTab': 'upcoming'},
);
```

**Owner (`_isWalker == false`):**
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (_) => ReviewBottomSheet(
    bookingId: _bookingId!,
    walkerId: _walkerId!,
    walkerName: _walkerName ?? 'your walker',
  ),
).then((_) => _navigateToBookingsPast());
```

`WalkerBookingsScreen` must accept an `initialTab` argument (`'upcoming'` or `'past'`). If it does not already support this, add it.

---

## Pending Review Detection (owner not on active walk screen)

**Query** (run at both entry points):
```sql
SELECT b.id, b.walker_id, u.full_name AS walker_name
FROM bookings b
JOIN walkers w ON b.walker_id = w.id
JOIN users u ON w.user_id = u.id
LEFT JOIN reviews r ON r.booking_id = b.id
WHERE b.owner_id = <current_user_id>
  AND b.status = 'walk_completed'
  AND r.id IS NULL
ORDER BY b.updated_at DESC
LIMIT 1
```

**Entry point 1 — `BookingsScreen`** (`lib/screens/bookings_screen.dart`):  
After `_loadBookings()` completes, run the pending review check. If a result is found and `_reviewPromptShown == false`, set `_reviewPromptShown = true` and call `showModalBottomSheet` with `ReviewBottomSheet`. Guard prevents re-showing on the same screen load.

**Entry point 2 — `_AuthGate`** (`lib/main.dart`):  
After the user is confirmed signed in and role is resolved, run the same check once per session. If a pending review is found, show `ReviewBottomSheet` over the initial screen using the navigator key.

**Push notification tap** (`lib/services/notification_service.dart`):  
When a notification with `data.review_prompt == "true"` is tapped (foreground or background), extract `booking_id`, `walker_id`, `walker_name` from the payload and show `ReviewBottomSheet` using the global navigator key.

---

## Error Handling

| Scenario | Behavior |
|---|---|
| Duplicate review insert | Snackbar: "You have already reviewed this walk" |
| Network error on submit | Existing `withRetry` + `ErrorHandler.handleError` snackbar |
| Missing booking_id / walker_id | Sheet does not open; silently skipped |
| Walker taps notification (shouldn't happen) | No `review_prompt` field in walker's notification — not applicable |

---

## Out of Scope

- Showing multiple queued pending reviews (only most recent surfaced)
- Owner rating display on walker profile (already handled by `avg_rating` trigger)
- Editing or deleting a submitted review
