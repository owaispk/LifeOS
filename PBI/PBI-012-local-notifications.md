# PBI-012 — Local Reminders & Actionable Notifications

| Field | Value |
|---|---|
| Epic | E5 Platform |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §12; UI flow §4; Data model §6.5 |
| Depends on | PBI-009 |
| Status | Ready |

## User Story
As a **user**, I want reminders that fire on time even without internet, and that I can act on without opening the app.

## Description
- `flutter_local_notifications` scheduling, driven by `task_reminders`
- Reschedule everything on app start, on device reboot, and after timezone changes
- Actionable notifications: payment → [Paid ✓] [Snooze]; expiry → [Set renewal task] [Dismiss]; task → [Done ✓] [Snooze]
- Notification permission is requested in context, when the first reminder is set
- Privacy: when app lock is on, titles are generic ("A payment is due tomorrow")
- Android exact-alarm permission is handled gracefully, with an inexact fallback

## Acceptance Criteria
1. A reminder set 2 minutes ahead fires in airplane mode.
2. Tapping [Paid ✓] marks the payment paid without opening the UI and triggers the completion chain (PBI-016).
3. Snooze reschedules for +1 h (configurable).
4. After a reboot, pending reminders are restored (tested on an Android emulator).
5. Deleting or completing a task cancels its pending notifications.
6. With app lock on, no notification shows an amount, document name or number.
