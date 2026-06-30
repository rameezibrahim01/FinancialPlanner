# V2 Scope — Offline Yearly Financial Planner

This document defines **V2**. It assumes **V1 is already built** (see `README.md` for the full v1 spec — all tokens, type, and patterns there still apply; V2 reuses the same calm-green system, AED currency, Hanken Grotesk + IBM Plex Mono, and all existing design tokens).

**Design file for V2:** `Finance Planner V2.dc.html` (open in a browser). It contains the 5 new/changed screens described below, labeled V2-1 … V2-5.

> Build rule: reuse v1 components, colors, and tokens. Do **not** restyle v1. Where a V2 screen replaces a v1 screen, swap it; where it's additive, slot it into the indicated lane/tab.

---

## V2-1 · Recurring bills & subscriptions  *(NEW — Plan lane)*
**Why:** Most of a month's spend is predictable. Let the user define recurring bills/subscriptions once so they auto-populate every month's plan and the upcoming list.

- **Entry point:** Plan tab → "Recurring".
- **Summary card** (green): total monthly recurring (e.g. AED 8,420/mo), active count, and annual committed amount (monthly × 12).
- **List:** each recurring item = tint icon + name + "category · cadence" + amount + due-day. Categories reuse v1 category colors.
- **Add recurring bill** (dashed tile) → form: name, amount, category, cadence (monthly/quarterly/annual), due day, auto-post on/off.
- **Behavior:**
  - Each active recurring item is auto-added to the matching month's plan and appears in C1/V2-2 "Upcoming".
  - Annual/quarterly items are **amortized** into a monthly equivalent for budgeting, but post as a single transaction on their real due date.
  - Editing a recurring item offers "this month only" vs "all future months".
- **Data:** `recurring: [{ id, name, amount, category, cadence, dueDay, autoPost }]`. Derived `monthlyTotal`, `annualCommitted`.

## V2-2 · Dashboard with "Safe to spend"  *(REPLACES v1 C1)*
**Why:** The most useful daily number is "how much can I spend today and still hit my plan." This becomes the new home screen.

- **Header:** greeting ("Hello, Sara") + month eyebrow + "On plan" status pill (same pill as v1).
- **Safe-to-spend hero** (green card): big "AED 212" = (remaining discretionary budget ÷ days left in month). Progress bar = month elapsed vs budget. Subtext: "AED 4,240 left this month · 20 days to go".
  - Formula: `safeToday = (monthBudget − committedRecurringRemaining − spentSoFar) / daysRemaining`. Floor at 0; turn clay if negative.
- **Three stat tiles:** Income / Spent (clay) / Saved (green) for the current month.
- **Upcoming this week:** next recurring charges (from V2-1) with due-in copy and clay amounts.
- **Tab bar:** Home (active) · Plan · + · Charts · Settings. *(Note: v1's tab label "Year" becomes "Home"; the year-grid moves under Plan or a segmented toggle on Home — implementer's choice, keep the 12-month grid reachable.)*
- **Data:** derived entirely from transactions + plan + recurring. No new persisted state.

## V2-3 · Debt payoff tracker  *(NEW — Goals)*
**Why:** Sits alongside Savings goals; many users plan around paying down debt.

- **Entry point:** Plan/Goals → "Debt payoff".
- **Summary card** (white): total remaining across debts, overall % paid, monthly amount directed to debt, projected debt-free date.
- **Debt cards:** name + "APR · term left" + balance + monthly payment + progress bar (% paid) + per-debt payoff date. Color the bar by rate severity (high-APR card uses clay).
- **Strategy toggle:** Avalanche (highest APR first) vs Snowball (smallest balance first) — recomputes payoff order/dates.
- **Add debt** → form: name, current balance, APR, minimum/planned monthly payment.
- **Behavior:** payments logged as transactions in a "Debt" category reduce the balance; projected payoff recalculated from planned monthly payment + APR.
- **Data:** `debts: [{ id, name, balance, apr, monthlyPayment, openingBalance }]`. Derived `fill = 1 − balance/openingBalance`, `payoffDate`, `strategy`.

## V2-4 · Backup, restore & export  *(NEW — Settings; fulfills v1's "Export backup" button)*
**Why:** Offline app = the user owns their data. Make backup/restore and export first-class.

- **Status card** (light-green): last backup time + "stored on this device".
- **Export section:** Export transactions (CSV) · Year report (PDF: summary, charts, categories) · Share backup file (`.planner`, full serialized state).
- **Backup section:** Auto-backup toggle (daily, to Files / iCloud Drive) · Create backup now · Restore from file.
- **Footer reassurance:** "All data stays on your device".
- **Behavior:**
  - CSV = flat transaction rows. PDF = rendered year summary. Backup = full JSON of all state (income, plan, transactions, goals, debts, recurring, settings).
  - Restore replaces/merges state from a chosen file (confirm before overwrite).
  - Auto-backup writes to a user-granted Files/iCloud location; **no server**.

## V2-5 · App lock (Face ID / passcode)  *(NEW — Security)*
**Why:** Financial data is sensitive; gate the app behind device biometrics.

- **Lock screen** (dark `#11271f` background — the one place dark is used): app mark, "Planner is locked", Face ID glyph, "Tap to unlock with Face ID", "Use passcode instead".
- **Behavior:**
  - On launch / return from background (after a configurable timeout), present the lock screen.
  - Authenticate with `LAContext` (Face ID/Touch ID) on iOS, or the platform biometric API; fall back to a passcode.
  - Toggle in Settings: App Lock on/off + auto-lock timeout (immediately / 1 min / 5 min).
- **Data:** `security: { appLock: bool, method: faceID|passcode, timeout }`. Passcode stored hashed in the Keychain — never in plain storage.

---

## Build order (suggested)
1. **V2-1 Recurring** — it feeds V2-2 and the plan; do it first.
2. **V2-2 Safe-to-spend dashboard** — depends on recurring + plan.
3. **V2-4 Backup/export** — finishes the v1 stub, low risk.
4. **V2-3 Debt payoff** — self-contained feature.
5. **V2-5 App lock** — wraps the app; do last.

## Out of scope for V2
Multi-currency, multi-account/wallets, receipt photos, net-worth tracking, widgets, cloud sync. (Candidates for V3.)
