# Handoff: Offline Yearly Financial Planner (iOS app)

## Overview
A personal finance app for iOS that lets a user **plan their whole year month-by-month** (income, category budgets, savings goals) and then **track actual income & expenses against that plan**. Everything is stored locally — the app works **100% offline, no account**. Currency is **AED**, year shown is **2026**.

The design is laid out as a four-stage user journey:
**Step 1 · Set up → Step 2 · Plan the year → Step 3 · Track → Step 4 · Review.**

## About the Design Files
The files in this bundle are **design references created in HTML** — a prototype showing the intended look, layout, and content. **They are not production code to copy directly.** The HTML uses a small in-house rendering runtime (`support.js`) and a mock iPhone bezel (`ios-frame.jsx`); neither should ship in the real app.

The task is to **recreate these designs in the target codebase's environment** using its established patterns. For a native iOS app the natural choice is **SwiftUI**; if you're building cross-platform, **React Native / Expo** is appropriate. Use whichever the project already uses. Persist all data on-device (SwiftData/Core Data/SQLite on iOS, or AsyncStorage/SQLite for RN) — there is no backend.

## Fidelity
**High-fidelity.** Colors, typography, spacing, and layout are final and should be matched closely. Exact hex values, font sizes, and the design-token table below are authoritative. The iPhone frame, status bar (9:41), and home indicator come from the mock bezel — reproduce them with the OS's real chrome, not as drawn elements.

## Screens / Views
There are **11 screens** across 4 lanes. Each is a 402×874 mock iPhone (logical points ≈ 393×852 for a modern iPhone). Page background is `#f1f1ec`; content sits below a ~54px status-bar inset.

### Lane 1 — Set up

**A1 · Welcome**
- Purpose: First launch; introduce the app and start setup.
- Layout: Vertically centered hero; CTA group pinned to bottom (24px side padding, 30px bottom).
- Components:
  - App mark: 72×72 rounded square (radius 22), fill `#1f6f54`, containing three ascending rounded bars (white / `#c8e6d8` / `#9bd2b8`) — represents a bar chart. Shadow `0 10px 26px rgba(31,111,84,0.32)`.
  - Headline: "Plan your whole year. Offline." — 30px / weight 800 / letter-spacing −0.8px / line-height 1.12.
  - Subtext: "Budget every month, track income & expenses, and hit your savings goals — all stored on your device." — 15px / `#5f6862` / line-height 1.5 / max-width 280px.
  - Offline badge: mono 11px `#1f6f54`, 6px green dot + "WORKS 100% OFFLINE · NO ACCOUNT".
  - Primary button: full-width, `#1f6f54` bg, white text 16px/700, radius 16, padding 16, shadow `0 8px 20px rgba(31,111,84,0.28)`. Text "Get started".
  - Secondary text button: "I already have a backup" — 15px/600 `#5f6862`.

**A2 · Income setup**
- Purpose: Add recurring income sources; baseline for plans.
- Layout: Header block, list of source cards, dashed "add" tile, spacer, projected-income summary bar, Continue button.
- Components:
  - Eyebrow: mono 11px `#8a928c` "SETUP · 1 OF 2". Title "Your income" 26px/800/−0.6px. Subtext 14px `#5f6862`.
  - Income source card (white, radius 18, padding 15×16, shadow `0 1px 2px rgba(20,40,30,0.04)`): 38×38 rounded tint square (radius 11) + name (15px/700) + cadence (12px `#8a928c`) + right-aligned amount (16px/800, tabular) + "recurring" (11px/600 `#1f6f54`). Sources: Salary / "Monthly · 1st" / AED 18,500 (tint `#dbeae1`); Freelance / "Avg / month" / AED 1,200 (tint `#e6ead7`).
  - Add tile: dashed border `1.5px #c9c9bf`, radius 18, "+ Add income source" 14px/600 `#5f6862`.
  - Summary bar: `#eaf2ed` bg, radius 18, "Projected annual income" (13px/600 `#1f6f54`) + "AED 236,400" (20px/800 `#1f6f54`).
  - Button: primary green "Continue to planning".

### Lane 2 — Plan the year (the core planning flow)

**B1 · Year Plan**
- Purpose: See & set the budget for all 12 months at once.
- Layout: Header, green summary card, table header row, scrollable 12-row table, two-button footer.
- Components:
  - Summary card: bg `#1f6f54`, radius 22, shadow `0 8px 22px rgba(31,111,84,0.22)`. "Planned to save in 2026" (13px `#bfe0cf`) + "115% of goal" pill (`#9bd2b8` bg, `#0f3527` text). Amount "AED 68,700" (36px/800 white). Three mini stats (Income 230,000 / Budget 161,300 / Goal 60,000) — labels `#9ec9b3` 11px, values `#eaf6f0` 15px/700.
  - Table: white card radius 18. Column header (mono 10px `#a0a89f`): MON / INCOME / BUDGET / SAVE, with "AED · THOUSANDS" note. 12 rows, each 43px tall, border-bottom `#f3f3ee`, 13px tabular figures. Month = mono 11px `#5f6862`; income & budget `#4a544e`; SAVE column bold `#1f6f54`; trailing chevron `›` `#cdd2cb`. Values are in thousands (e.g. 18.5, 13.0, +5.5). Apr income 21.0, Dec 24.0/16.3/+7.7.
  - Footer: two buttons side-by-side — "Copy to all months" (white, border `#e2e2d8`, `#1f6f54` text) and "Edit a month" (primary green).

**B2 · Month Plan editor** ★ (most important planning screen)
- Purpose: Set income and per-category budgets for one month; see resulting planned savings.
- Layout: Nav row (‹ / title / Save), planned-income+savings card with allocation meter, category-budget list with sliders.
- Components:
  - Nav: 34×34 white circle back button `‹`; title "March 2026 plan" 17px/700; "Save" 15px/700 `#1f6f54`.
  - Card (white, radius 20): "Planned income" 14px `#5f6862` + "AED 18,500" 18px/800. Divider `#ecece6`. "Planned savings" + "AED 5,300 · 29%" (20px/800 `#1f6f54`, the % is 13px `#8a928c`). Allocation meter: 9px track, split 71.4% `#c19a4a` (budgeted) / 1px white gap / 28.6% `#1f6f54` (savings); labels below "AED 13,200 budgeted" / "AED 5,300 to savings" (11px `#8a928c`).
  - "Category budgets" header + "+ Add" (12px/600 `#1f6f54`).
  - Category rows (7), each: 9px color square + name (13px/600) + amount (14px/700 tabular) on top; below a 6px slider track `#ecece6` with colored fill to `fill%` and a 16px white knob (2px colored border, shadow) centered at `fill%`. Rows: Housing 5,000 (100%, `#1f6f54`), Groceries 2,400 (48%, `#7a8b3f`), Shopping 1,500 (30%, `#8b6b3f`), Transport 1,300 (26%, `#3f6f8b`), Dining 1,200 (24%, `#bd5a3c`), Utilities 1,000 (20%, `#6b7d6f`), Health 800 (16%, `#8b3f5a`).

**B3 · Plan vs Actual**
- Purpose: Track this month's spend against its budget, per category.
- Layout: Nav (‹ + centered title/subtitle), budget-progress card, per-category bars.
- Components:
  - Title "June · plan vs actual" 17px/700; subtitle mono 10px `#1f6f54` "ON TRACK · 2 DAYS LEFT".
  - Progress card (white, radius 22): "Spent of budget" + "9,840 / 12,000" (32px/800 with 16px `#8a928c` denominator) + "Left 2,160" (18px/800 `#1f6f54`). 10px track, 82% fill `#1f6f54`. "82% of June budget used" 11px `#8a928c`.
  - Category rows (6): color square + name + "actual / plan" (actual bold; `#bd5a3c` if over, else `#15201a`; plan `#a0a89f`). 6px bar filled to `actual/plan` (capped 100%), bar `#bd5a3c` when over else category color. Rows: Housing 5,000/5,000 (100%), Groceries 1,980/2,400 (83%), Dining 1,460/1,200 (OVER, clay), Transport 640/1,300 (49%), Utilities 760/1,000 (76%), Shopping 0/1,100 (0%).

**B4 · Savings goals**
- Purpose: Set/track savings goals and contribution pace.
- Layout: Header, hero goal card with progress ring, other-goals list, "+ New goal" tile.
- Components:
  - Hero card (white, radius 22, centered): 140×140 progress ring via conic-gradient `#1f6f54 0% 64%, #e7e7e0 64% 100%` with 108px white inner circle showing "64%" (28px/800 `#1f6f54`) + "funded". "New car" 18px/800; "AED 38,400 of 60,000 · by Dec 2026" 14px `#5f6862`. Status pill `#eaf2ed`: "On track · AED 5,000/mo reaches it by Nov".
  - Other goals (cards radius 16): name (14px/700) + "saved / target" + 7px progress bar + note (11px `#8a928c`). Emergency fund 22,000/25,000 (88%, green); Japan trip 6,300/15,000 (42%, `#3f6f8b`).
  - "+ New goal" dashed tile.

### Lane 3 — Track

**C1 · Dashboard (home)**
- Purpose: Year-at-a-glance of actuals; app home.
- Layout: Header (2026 + "On plan" pill), net-saved card, "At a glance" 12-month grid (3 cols), bottom tab bar.
- Components:
  - Header: eyebrow mono "ANNUAL · AED" + "2026" 30px/800. Pill `#dbeae1`/`#1f6f54` with dot: "On plan".
  - Net card (white, radius 24): "Net saved this year" + "28% rate" pill (`#eef6f1`/`#1f6f54`). "AED 63,700" (38px/800 `#1f6f54`, AED prefix 16px `#4a544e`). Divider. Two cells: Income 230,000 (green dot) / Expenses 166,300 (clay dot), values 18px/700.
  - Month grid: 12 white cells (radius 15), each: mono month abbr `#a0a89f`; net short (17px/800, `#1f6f54` or `#bd5a3c` if negative); 5px spend-ratio bar + mono "% spent". Bar color: green normally, `#d39a4a` if ≥85%, `#bd5a3c` if over. Oct is negative (−0.4k / 102% spent).
  - Tab bar: Year (active `#1f6f54`/700) · Plan · [center + button: 46px green circle, white +, lifted −22px, shadow] · Charts · Settings. Inactive labels `#a0a89f` 11px. Bar bg `rgba(241,241,236,0.92)`, top border `#e6e6df`, bottom padding 26 for home indicator.

**C2 · Monthly breakdown**
- Purpose: Detail of one month (October — an over-budget month).
- Layout: Nav (‹ / title+OVER BUDGET / ›), net card, "Where it went" category bars, "Recent" transaction list.
- Components:
  - Title "October 2026"; sublabel mono 10px `#bd5a3c` "OVER BUDGET".
  - Net card: "Net this month" + "−400" (22px/800 `#bd5a3c`). Split bar 49.5% green / 50.5% clay. Legend: Income 18,500 / Spent 18,900.
  - Category list (6): color square + name + amount + 6px bar. Housing 5,000 (100%), Shopping 4,300 (86%), Other 3,520 (70%), Groceries 2,650 (53%), Dining 2,180 (44%), Transport 1,250 (25%).
  - Recent list (white card, radius 20): rows = 34px tint square + name (14px/600) + sub (11px `#a0a89f`) + amount (14px/700, green if +, clay if −). Salary +18,500; Rent −5,000; IKEA −2,150; DEWA −1,020; Carrefour −418.

**C3 · Add transaction**
- Purpose: Enter a new income/expense.
- Layout: Header (Cancel/title/Save), Expense|Income segmented control, large amount display, category chip grid, detail rows, numeric keypad.
- Components:
  - Segmented control: `#e7e7e0` track radius 13, active half white with shadow; "Expense" active (`#bd5a3c` text), "Income" inactive (`#8a928c`).
  - Amount: mono "AMOUNT" label; "AED" 20px `#8a928c` + "86.00" 48px/800 `#bd5a3c` + 2px blinking caret.
  - Chips: 3×2 grid; each = 18px color square + name (11px/600). Active chip (Dining) has `#f7e8e1` bg + `1.5px #bd5a3c` border + clay text; others white bg/border, `#4a544e` text. Chips: Groceries, Dining(active), Transport, Shopping, Bills, Health.
  - Detail rows (white card radius 16): Date "Today · Jun 29"; Note "Dinner · Zuma". Label `#8a928c`, value 600.
  - Keypad: 3×4 grid, keys 1-9, ., 0, ⌫. Each white tile 50px, radius 14, 23px/600, shadow `0 1px 2px rgba(0,0,0,0.04)`.

### Lane 4 — Review

**D1 · Charts & trends**
- Purpose: Visualize cash flow over the year.
- Layout: Header, 3 stat cards, "Net by month" bar chart, "Top categories" list, tab bar (Charts active).
- Components:
  - Stat cards (white radius 14): Avg/month +5,308; Best Apr +9.4k (`#1f6f54`); Worst Oct −0.4k (`#bd5a3c`).
  - Bar chart (white card radius 20): 12 bars, height in px from data, radius `5px 5px 2px 2px`, green (clay for Oct), mono month letter beneath. Chart area 118px tall, bars bottom-aligned.
  - Top categories (6): color square + name + "amount · pct" + 6px bar. Housing 60,000/36%, Groceries 28,400/17%, Other 19,400/12%, Dining 18,900/11%, Transport 14,200/9%, Shopping 13,600/8%.

**D2 · Year in review & settings**
- Purpose: Year summary stats + data/settings + backup.
- Layout: Header, 2×2 stat grid, "Data & settings" list, "Export backup file" button.
- Components:
  - Stat grid: Total saved 63,700 (green card, white text, "vs 60,000 planned"); Savings rate 28%; Biggest cost Housing (36% · 60,000); Months on budget 11 of 12 ("only Oct over").
  - Settings list (white card radius 18): rows = 30px tint square + name + value + chevron. Currency AED; Monthly reminders On; Local backup Daily; Categories 8; Roll over balance On.
  - Button: primary green "Export backup file".

## Interactions & Behavior
- **Navigation:** Bottom tab bar (Year / Plan / Charts / Settings + center Add) on the tracking/review screens. Back chevrons (‹) on detail/editor screens. The canvas arrows show the intended journey order, not literal in-app links.
- **Add transaction:** Tapping the center + opens C3. Segmented control toggles Expense (clay accent) vs Income (green accent), which recolors the amount. Category chip selection is single-select. Keypad edits the amount; ⌫ deletes. Save persists and returns.
- **Month plan editor (B2):** Each category slider sets that category's budget. As budgets change, "Planned savings" = income − sum(budgets) and the allocation meter updates live. If sum(budgets) > income, savings goes negative — surface as a warning (clay).
- **Plan vs Actual (B3):** Bars fill to actual/plan; categories over budget turn clay and the actual figure turns clay. The header status ("ON TRACK" / "OVER") derives from total spent vs total budget.
- **Year Plan (B1):** Rows tap into B2 for that month. "Copy to all months" applies the current month's category budgets to every month.
- **Savings goals (B4):** Progress ring = saved/target. Pace note compares required monthly contribution to planned monthly savings.
- **Transitions:** Standard iOS push for detail screens; modal sheet for Add transaction. Amount caret blink ~1s. No elaborate custom animation required for v1.

## State Management
- **Income sources:** `[{ name, cadence, amount, recurring }]` → projected annual income.
- **Year plan:** per-month `{ month, plannedIncome, categoryBudgets: {category: amount} }`; derived `budgetTotal`, `plannedSavings = income − budgetTotal`.
- **Transactions:** `[{ id, type: income|expense, amount, category, date, note, account }]` — the source of truth for all actuals.
- **Derived (computed from transactions + plan):**
  - Monthly actual income/expense/net (Dashboard grid, Monthly breakdown).
  - Spend ratio = monthExpense / monthIncome.
  - Plan-vs-actual per category = sum(transactions in category, month) vs budget.
  - Year totals, savings rate = net / income, best/worst month, category breakdown.
- **Goals:** `[{ name, target, saved, deadline, monthlyContribution }]`; derived `fill = saved/target`, on-track check.
- **Settings:** currency (AED), reminders, backup cadence, categories list, roll-over flag.
- **Persistence:** all local (SwiftData/Core Data/SQLite or RN equivalent). Export backup = serialize all state to a file the user saves/shares. No network.

## Design Tokens

**Colors**
| Token | Hex | Use |
|---|---|---|
| Page background | `#f1f1ec` | App background |
| Surface / card | `#ffffff` | Cards, lists |
| Ink (primary text) | `#15201a` | Headlines, values |
| Ink secondary | `#4a544e` | Secondary values |
| Muted text | `#8a928c` | Labels, captions |
| Faint text / icons | `#a0a89f` | Mono micro-labels, chevrons |
| Hairline | `#ecece6` / `#f3f3ee` | Dividers, track bg, row borders |
| Border | `#e2e2d8` / `#e6e6df` | Button & bar borders |
| Dashed border | `#c9c9bf` | Add tiles |
| **Primary green** | `#1f6f54` | Brand, income, positive, CTAs |
| Green soft | `#dbeae1` / `#eaf2ed` / `#eef6f1` | Tints, pills |
| Green on-dark text | `#bfe0cf` / `#9ec9b3` / `#eaf6f0` | Text on green card |
| Green accent (goal pill) | `#9bd2b8` | Pill on green card |
| Green dark | `#0f3527` | Text on light-green pill |
| **Expense clay** | `#bd5a3c` | Expense, negative, over-budget |
| Clay soft | `#f7e8e1` | Active expense chip bg |
| Warn amber | `#d39a4a` / `#c19a4a` | High spend ratio (≥85%), budget portion |
| Category — Groceries | `#7a8b3f` | |
| Category — Transport | `#3f6f8b` | |
| Category — Shopping | `#8b6b3f` | |
| Category — Utilities | `#6b7d6f` | |
| Category — Health | `#8b3f5a` | |
| Category — Other | `#8a928c` | |

**Typography**
- UI / body: **Hanken Grotesk** (Google Fonts), weights 400/500/600/700/800. iOS substitute: SF Pro is acceptable, but Hanken matches the design — bundle it.
- Numeric labels / eyebrows / micro-text: **IBM Plex Mono** (Google Fonts), 400/500/600, letter-spacing ~0.4–0.5px, often UPPERCASE.
- All money figures use **tabular figures** (`font-variant-numeric: tabular-nums`).
- Scale: Display title 30px/800 (−0.8px); screen title 26px/800 (−0.6px); hero amount 36–48px/800 (−1px); section header 15–17px/700; body 13–15px; label 11–13px; micro/mono 9–11px.

**Spacing**
- Screen side padding: 16px (cards/lists), 18–22px (headers/text). Card padding: 15–20px. Section gaps: 14–18px. Element gaps: 8–14px. Bottom safe padding above home indicator: ~26–30px.

**Radius**
- Cards 18–24 · large summary 22–24 · buttons/tiles 14–16 · chips/tiles 14 · small tint squares 6–11 · pills/bars/dots 999 (full).

**Shadows**
- Card: `0 1px 2px rgba(20,40,30,0.04)`. Primary button: `0 8px 20px rgba(31,111,84,0.28)`. Green summary card: `0 8px 22px rgba(31,111,84,0.22)`. Tab + button: `0 6px 16px rgba(31,111,84,0.35)`. App mark: `0 10px 26px rgba(31,111,84,0.32)`.

## Assets
- **No raster images.** All visuals are CSS/typography. The app mark is three rounded bars in a rounded square — rebuild it natively (or export an app icon from it).
- **Fonts:** Hanken Grotesk + IBM Plex Mono — bundle as app fonts (don't rely on web links).
- **Icons:** category markers are plain colored squares/dots in the mock. In the real app, substitute system icons (SF Symbols) per category if desired, keeping the category colors above. Status-bar/home-indicator/keyboard are mock chrome — use the OS's real components.
- **Currency:** AED, thousands separator with comma, no decimals except the Add-amount field (2 decimals).

## Files
In this bundle:
- `Finance Planner.dc.html` — the full design (all 11 screens on one canvas). Open in a browser to view.
- `ios-frame.jsx` — mock iPhone bezel/status bar (reference only; do not ship).
- `support.js` — the prototype's rendering runtime (reference only; do not ship).

To view: open `Finance Planner.dc.html`. The 11 screens are grouped into the four lanes described above; the canvas arrows indicate the intended user journey.
