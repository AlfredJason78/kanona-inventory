# AGENTS.md — Instructions for AI assistants working on Kanona

Read `README.md` first. It contains the full specification: database schema, screens, design tokens, and build plan. This file tells you **how to work**, not what to build.

---

## The project in one paragraph

Kanona is an inventory system for a clothing store with colour and size variants. 2–4 users. It answers one question correctly: how many of each variant do we have right now, and why is it that number. It is **not** an ERP — no accounting, purchasing, suppliers, or finance. Stack: Next.js + TypeScript, Tailwind + shadcn/ui, Supabase (PostgreSQL + Auth + Storage + RLS + Edge Functions). All UI labels are in Bahasa Indonesia.

---

## How to work with this user — READ THIS FIRST

**The user is learning to code. They want the necessary code handed to them as a block in chat, which they then type into the editor themselves.** Do not write it into the project's files yourself unless they explicitly ask you to fix or edit code directly — that permission is per-request, not a standing switch to writing files for them.

This is the single most important instruction in this file. Ignoring it defeats what the user actually asked for.

### Give code in chat; only touch files on explicit request

When they ask for a feature:

1. Explain briefly what needs to be built and why
2. Give the full implementation as a code block in your reply — real, complete, working code, not fragments they have to assemble — for them to type in themselves
3. Tell them which file it goes in
4. Point out the one or two things worth understanding in it (a non-obvious constraint, why a check exists, why a hook is used) — not a line-by-line narration of the whole block
5. Tell them how to verify it works (run it, click through it, check the DB row)

**Only create or edit a file yourself when they explicitly ask you to** — "fix this," "edit that file," "just do it this time." Absent that, hand over the code block and let them type it. When they do ask you to fix something directly, go ahead and edit the file — that instruction doesn't need re-confirming each time within the same request.

Still name trade-offs when there are two reasonable approaches, and still say clearly when something is wrong, risky, or just taste. Explaining reasoning is not the part that changed.

### When explaining

Explain **why**, not just how. Do not say "use `useRef` here" — say that a value in `useRef` does not trigger a re-render, and that is why it suits keeping focus in the barcode scan field.

If there are two reasonable approaches, name both with their consequences, then recommend one. Do not hide the choice from them.

### When reviewing their code

Say what is wrong and why it is a problem, then let them fix it. If there are three problems, lead with the most important — do not dump a long list that overwhelms them.

Separate clearly:

- **Wrong** — will cause a bug
- **Risky** — works now, breaks later
- **Taste** — your way differs but theirs is valid

### When they misunderstand something

Correct it directly. Do not agree first and then quietly write something different. If their request will cause a problem, say so before doing it.

### Do not run ahead

Do one thing they asked for. Do not add features, refactor unrelated parts, or "fix while you're in there". If you notice something that needs fixing, mention it after finishing — do not just do it.

---

## Pacing: they have three weeks

They are aiming for a working system in three weeks with no prior experience. That changes what good advice looks like.

**Prefer the boring solution.** Every new library is a new thing to learn. `.filter()` beats TanStack Table here. `useState` beats React Hook Form here. `<input type="date">` beats a date picker library.

**Do not suggest abstractions before there is repetition.** Three similar pages is the moment to extract a shared component — not the first one.

**If they are behind schedule**, the cut order is: Print Settings page → Barcode page → Dashboard. Never cut the `expected_stock` check, the append-only history, or the RLS policies.

**Follow the build order in README.md.** Database first, then one complete feature from database to screen. If they ask for the Dashboard before stock transactions exist, remind them the Dashboard only reads data that is not there yet.

---

## Rules that must never be broken

These are not style preferences. Breaking any of them produces wrong stock numbers or an unauditable system.

### 1. Stock history is append-only

Rows in `stock_movements` are **never** updated or deleted. Corrections are new rows. A cancelled order writes a positive `order_cancelled` row; the original deduction stays untouched.

If the user asks to "just fix that wrong row", explain why the answer is a correcting row instead.

### 2. Every stock change is atomic

Change the stock and write the history row in **one transaction**. Never one without the other.

All four stock sources must go through the `record_stock_movement` database function — not through a series of queries from the app. That is what makes it impossible for a code path to forget the history.

### 3. Current stock is a result, not a fact

`variants.current_stock` is a cache. The truth is the sum of the movement rows. Never update it outside the function above.

### 4. Role restrictions live in the database

Hiding a tab stops a click, not a request. Every restriction in the permission table must also be an RLS policy.

If the user hides a tab in the UI and moves on, remind them the policy is missing.

### 5. Ask about capability, never job title

```jsx
{can(role, 'manageProducts') && <button>Buat Produk</button>}   // ✅
{role === 'owner' && <button>Buat Produk</button>}              // ❌
```

All permissions live in one file, `lib/permissions.ts`. If you see `role === 'owner'` inside a component, flag it.

Why: if Managers are later allowed to add variants, the first version changes one line. The second means hunting through a dozen files, and one missed spot is a button that appears but fails.

### 6. Store at the finest grain

Stock moves per **variant**, never per product. The display may summarise; the storage may not.

### 7. Passwords never live in code

The owner's initial password is read from an environment variable by the seed script, hashed by Supabase Auth, and only the hash reaches the database. Confirm `.env.local` is in `.gitignore` before the first commit.

### 8. Users are not deleted

Staff who leave are deactivated (`is_active = false`), because their name is still referenced by history rows.

---

## The `expected_stock` check — do not let this get simplified away

This is the safeguard most likely to be dropped as "unnecessary complexity". It is not.

Two people can count the same shelf. When Save is pressed, the server compares the current stock with the number that was on screen when the page opened. If it changed, the save is refused:

> "Stok sudah berubah dari 64 menjadi 58. Muat ulang?"

Notes:

- This is **not** real time. The number on screen sits still. Only the save is checked.
- Do not replace it with Supabase Realtime. For 4 users the cost outweighs the benefit, and Realtime cannot pull orders from Shopee so it replaces nothing.
- Do not use `useOptimistic` for stock numbers. Showing the new figure before the server confirms is exactly backwards — the server is the thing that checks.

---

## Marketplace sync — the guard matters

A scheduled job pulls orders every 3 minutes. It **will see the same order many times**. Every order row has `stock_deducted`; if set, skip it. Without that guard, stock is deducted repeatedly for one sale.

Stock is deducted when the order status becomes `processing`. The status belongs to the marketplace — Kanona only displays it. The four statuses are `pending`, `processing`, `shipped`, `cancelled`; do not invent more.

---

## Language

All UI text is in **Bahasa Indonesia** — labels, menus, buttons, form fields, table headers, dialogs, empty states. Variable names and code comments may be English.

Terms already established in the design, do not rename:

Stok Masuk · Stok Keluar · Audit Stok · Riwayat Stok · SKU Induk · Kode Varian · Stok Sistem · Stok Fisik · Selisih · Perlu Perhatian · Sinkron Terakhir · Reset Filter · Hubungkan Ulang

Role names: **Owner**, **Manager**, **Admin**. Never "Supervisor" or "Staff" — those are old names from an earlier draft.

---

## The design reference

`kanona-ui-template.html` is the finished design as a single static HTML file. Open it in a browser to see every screen and dialog.

**How to use it:** read the markup and lift the exact values — hex codes, spacing, sizes, radii, table column widths. The visual design is final and should be reproduced closely.

**How not to use it:** do not copy it as production code. It is one file with inline sample data and a hand-rolled router, because it is a design reference. In the real app, break it into components, use Tailwind classes, and fetch real data.

All data in it is **sample data**. Product names and SKUs match the seed data in `README.md` so results are easy to compare.

---

## What to say no to

If the user proposes any of these, ask what problem they are solving before agreeing:

| Proposal | Why to push back |
|---|---|
| MongoDB | no row locking — breaks the `expected_stock` safeguard directly; no foreign keys |
| Supabase Realtime | cost outweighs benefit at 4 users; cannot pull Shopee orders |
| Redis, GraphQL, websockets | answer scale problems a 4-person system does not have |
| Microservices, Kubernetes, VPS | more parts that can break, no capability gained |
| A generic "settings" table | the schema in README.md is deliberate; keep columns explicit |
| Storing stock per product | breaks the finest-grain rule permanently |
| Soft-deleting history rows | history is append-only, full stop |

Saying no is part of the job here. The user is learning, and a wrong architectural suggestion accepted early costs weeks later.

---

## Full stock take (opname) — deliberately deferred

Stock Audit is a *cycle count*: pick a few variants, count, save, applied immediately.

A full monthly stock take is a different feature and needs four things: a session with states (open → counting → closed), a freeze period locking Stock In and Manual Stock Out, a count sheet showing which variants are not yet counted, and a summary before closing.

It is deferred on purpose and is cheap to add later: two new tables plus one nullable column, nothing touching existing data. If the user asks about it, do not talk them into building it now — but if the shop already plans to close for a full count at month end, it should come right after Week 3.

---

## Before handing anything to the client

- Upgrade Supabase to Pro (automatic daily backups)
- **Test restoring a backup.** A backup never restored often cannot be restored
- Change the owner's password, so the `.env` value no longer means anything
- Confirm `marketplace_connections.credentials` is never sent to the client
- Walk the whole system as Manager and Admin, not only as Owner
