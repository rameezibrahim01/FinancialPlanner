# Backlog

Deferred items to pick up later. Newest at the top of each section.

## Transactions
- [ ] **Edit / delete a transaction after it's added.**
  Today `AddTransactionView` is add-only — there's no way to modify or remove an
  entry (whether added manually, via the Siri/Shortcuts "Log Expense" intent, or
  auto-posted from a recurring bill) once it's recorded. Add an edit + delete
  flow — e.g. tap a row in **Recent activity** (Today) or the **Monthly
  breakdown** to open an editor sheet, plus swipe-to-delete. Reuse the
  `AddTransactionView` fields in an "edit" mode, and keep the recurring link
  (`recurringID`) intact when editing an auto-posted entry.

## Offline capture (from the earlier options list)
- [ ] Receipt scanning (VisionKit / Vision on-device OCR)
- [ ] Interactive Home/Lock-screen widget with quick "Log expense"
- [ ] CSV / statement file import (offline parse)
- [ ] Apple Watch app + complication
- [ ] Local notification reminders (bring back properly)
