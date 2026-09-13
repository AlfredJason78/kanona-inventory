# Kanona — Fashion Inventory System

Everything you need to build this system, in one file.

**What it is:** an inventory system for a clothing store. It answers one question correctly: *how many of each item do we have right now, and why is it that number?*

**What it is not:** an ERP. No accounting, no purchasing, no suppliers, no finance.

**Who uses it:** 2–4 people in one shop. A warehouse worker should learn it in 30 minutes, and every common action should take 3 clicks or fewer.

---

## Table of contents

1. [The three levels of data](#1-the-three-levels-of-data)
2. [User roles](#2-user-roles)
3. [The four ways stock changes](#3-the-four-ways-stock-changes)
4. [The one path all stock changes take](#4-the-one-path-all-stock-changes-take)
5. [Tech stack](#5-tech-stack)
6. [Database schema](#6-database-schema)
7. [Relationship diagram](#7-relationship-diagram)
8. [Project file tree](#8-project-file-tree)
9. [React hooks you need](#9-react-hooks-you-need)
10. [Design tokens](#10-design-tokens)
11. [The 12 screens](#11-the-12-screens)
12. [The 3-week build plan](#12-the-3-week-build-plan)
13. [Rules you must not break](#13-rules-you-must-not-break)

---

## 1. The three levels of data

This is the most important idea in the whole system. Get it wrong and nothing else works.

**Product** — the item in general. "Long Sleeve Oxford Shirt". A product has **no stock**. You cannot sell it. It is just a container.

**Variant** — the actual thing on the shelf. "Oxford Shirt, Navy, size L". This is what has stock, a price, and a barcode. One product can have 8 variants.

**Stock movement** — a record of every single time a variant's quantity changed. This is the most important table in the system.

The SKU shows the relationship:

```
Product parent SKU:   KMJ-OXF
Variant code:                 NVY-L
Variant SKU:          KMJ-OXF-NVY-L
```

This is why, in the Add Variant dialog, the `KMJ-OXF-` part cannot be edited. Consistency is enforced by the shape of the form, not by the staff member being careful.

---

## 2. User roles

Three roles. One Owner only; many Managers and Admins.

| Action | Owner | Manager | Admin |
|---|:---:|:---:|:---:|
| View Dashboard | ✅ | ✅ | ✅ |
| View Products & Product Detail | ✅ | ✅ | ✅ |
| Create / edit / delete products | ✅ | ❌ | ❌ |
| Create / edit / delete variants | ✅ | ❌ | ❌ |
| Stock In | ✅ | ✅ | ✅ |
| Stock Out — Marketplace tab | ✅ | ✅ | ✅ |
| Stock Out — Manual tab | ✅ | ✅ | ❌ |
| Stock Audit | ✅ | ✅ | ✅ |
| View Stock History | ✅ | ✅ | ✅ |
| Print barcodes | ✅ | ✅ | ✅ |
| View Marketplace page | ✅ | ✅ | ✅ |
| Reconnect a marketplace channel | ✅ | ❌ | ❌ |
| Settings — Categories (full CRUD) | ✅ | ✅ | ✅ |
| Settings — Users tab | ✅ | ❌ | ❌ |
| Create / edit staff accounts | ✅ | ❌ | ❌ |
| Activate / deactivate accounts | ✅ | ❌ | ❌ |
| Reset a staff password | ✅ | ❌ | ❌ |
| Change own password | ✅ | ❌ | ❌ |

Two rules about this table:

**Hide, don't disable.** A tab a role cannot use is not rendered at all. If only one tab is left, the tab bar disappears too.

**Enforce it in the database, not just the screen.** Hiding a button stops a click. It does not stop a request. Every restriction above must also exist as a database policy — otherwise it is decoration.

### Ask about capability, never about job title

Write your permissions in **one** file:

```js
// lib/permissions.js
export const PERMISSIONS = {
  manageProducts:   ['owner'],              // Manager may be added later
  manageUsers:      ['owner'],
  reconnectChannel: ['owner'],
  manualStockOut:   ['owner', 'manager'],
  stockIn:          ['owner', 'manager', 'admin'],
  stockAudit:       ['owner', 'manager', 'admin'],
  printBarcode:     ['owner', 'manager', 'admin'],
  manageCategories: ['owner', 'manager', 'admin'],
};

export function can(role, action) {
  return PERMISSIONS[action]?.includes(role) ?? false;
}
```

Then components ask:

```jsx
{can(role, 'manageProducts') && <button>Create Product</button>}
```

Never this:

```jsx
{role === 'owner' && <button>Create Product</button>}   // ❌ don't
```

Why it matters: if you later decide Managers may add variants, the first version changes **one line**. The second version means hunting through a dozen files, and one you miss becomes a button that appears but fails.

---

## 3. The four ways stock changes

Four different triggers. All four go through **the same single path**.

| Trigger | Who does it | Direction |
|---|---|---|
| **Stock In** | staff scans barcode, types quantity | up |
| **Manual Stock Out** | staff records damaged / lost / internal use | down |
| **Stock Audit** | staff counts the shelf, types the real number | up or down |
| **Marketplace order** | nobody — a scheduled job pulls it every 3 minutes | down |

---

## 4. The one path all stock changes take

One database function, `record_stock_movement`. Five steps, all inside **one transaction**:

```
1. Lock the variant row          SELECT ... FOR UPDATE
2. Compare current stock with the number the staff saw on screen
   ├── different? → cancel, and say:
   │   "Stock changed from 64 to 58. Reload?"
   └── same? → continue
3. Insert a stock_movements row  (before, change, after, activity, source, user)
4. Update variants.current_stock
5. Commit
```

If any step fails, all of it is undone. It is **impossible** for stock to change without its history row being written, or the other way round.

### Why step 2 exists

Two people can count the same shelf. Without that check, whoever saves last silently overwrites the first person's work and nobody ever finds out.

This is **not** real time. The number on screen sits still while the page is open. The check happens only at the moment Save is pressed. One extra check on one request — no persistent connection, no broadcasting to other screens.

### The number in the variants table is only a copy

The truth lives in the history. If you add up every movement row since the beginning, the total must equal `variants.current_stock`.

That is why history rows are **never edited or deleted**. Corrections are made by adding a new row. A cancelled order writes a "Order Cancelled" row that adds the quantity back — the original deduction row is left untouched.

---

## 5. Tech stack

Six things. That is all.

| Layer | Choice | Why |
|---|---|---|
| Database | **PostgreSQL** | Row locking. This is the one non-negotiable choice |
| Backend | **Supabase** | PostgreSQL + login + file storage + scheduling, no server to run |
| Framework | **Next.js** | One project for both screen and server |
| Language | **TypeScript** | Catches `"42" + 120 === "42120"` before it ships |
| Styling | **Tailwind CSS** | The design is built from fixed values already |
| Components | **shadcn/ui** | Code you copy into your project, so you can read and change it |
| Barcode | **bwip-js** | Generates the Code 128 image. One small job |

### Why PostgreSQL and not the others

**MongoDB — not suitable.** It has no row locking like `SELECT ... FOR UPDATE`. That breaks your most important safeguard directly: two people count the same shelf, and the last one to save overwrites the first with no warning. It also has no foreign keys, so a bug in your code could delete a variant that a thousand history rows still point to.

**MySQL — usable, but Postgres fits better.** Modern MySQL has transactions and row locks, so the critical part is safe. Postgres wins on three things: **Row Level Security** (permission rules live inside the database, so they hold even if your server code has a bug), real `enum` and `jsonb` types, and Supabase is built on it.

The thread connecting all of it: **wrong stock costs more than slow stock.** Postgres chooses strictness at every fork.

### Not using, on purpose

**Supabase Realtime** — for 4 people the cost outweighs the benefit, and it cannot pull orders from Shopee anyway, so it replaces nothing.

**TanStack Table** — your tables need sort, filter, and scroll. That is `.filter()` and `.sort()`. Worth adding later if Stock History grows to tens of thousands of rows in the DOM.

**React Hook Form** — your biggest form has six fields. `useState` is enough. Learn controlled forms by hand first; otherwise when something behaves oddly you cannot tell a React problem from a library problem.

**A date picker** — `<input type="date">` is already in the browser, free, and already in Indonesian.

**Redis, GraphQL, websockets, microservices, Docker, VPS** — all answer scale problems a 4-person system does not have. They only add parts that can break.

### Barcode type: Code 128

The barcode contains **the SKU itself** — `KMJ-OXF-NVY-L`. When scanned, what lands in the search box is exactly what is printed on the label. If the scanner fails, staff can type it by hand because the characters match. No translation table between barcode number and SKU, so there is nothing that can drift apart.

EAN-13 (the supermarket kind) is only needed if your products are sold in **someone else's shop** scanned by their till. Those numbers must be bought from GS1 Indonesia. If you sell only through your own channels, that is a cost with no benefit.

### Hosting and cost

**Vercel** for the app (free tier). **Supabase** for everything else — free while learning, then **Pro** (~Rp 400k/month) when a real shop depends on it. The single reason to upgrade: automatic daily backups.

No VPS. A VPS is about Rp 300k/month cheaper, and what you buy with that difference is not having to run backups, security updates, and monitoring yourself.

---

## 6. Database schema

Written as SQL you can type. Do this part first — it is the hardest thing to change later.

### Enums

```sql
create type user_role      as enum ('owner', 'manager', 'admin');
create type movement_type  as enum ('stock_in', 'stock_out', 'adjustment', 'order_cancelled');
create type order_status   as enum ('pending', 'processing', 'shipped', 'cancelled');
create type channel_name   as enum ('shopee', 'tokopedia', 'tiktok_shop');
```

Write **all three role values from the very first migration**, even though only Owner has full rights at the start. Adding a value to a Postgres enum later is awkward inside a transaction; writing them now costs nothing.

### profiles

Linked one-to-one with Supabase's own `auth.users`. Holds what Supabase Auth does not manage.

```sql
create table profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text        not null,
  role          user_role   not null,
  is_active     boolean     not null default true,
  last_login_at timestamptz,
  created_at    timestamptz not null default now()
);

-- only one owner may ever exist
create unique index one_owner_only on profiles (role) where role = 'owner';
```

**Users are never deleted.** A staff member who leaves gets `is_active = false`. Because `stock_movements.user_id` points here, deleting would cripple the history.

Setting `is_active = false` refuses the *next* login but does **not** end a session already running — a token already issued stays valid until it expires. If someone must be locked out immediately, also call `auth.admin.signOut()` for that user in the same transaction.

### categories

```sql
create table categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  created_at timestamptz not null default now()
);
```

The "Product count" column in Settings is **calculated**, not stored.

### products

```sql
create table products (
  id                   uuid primary key default gen_random_uuid(),
  name                 text not null,
  parent_sku           text not null unique,       -- 'KMJ-OXF'
  category_id          uuid not null references categories(id),
  photo_path           text,                        -- path in Supabase Storage
  low_stock_threshold  int  not null default 10,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
```

No status column. Product status was removed from the system — status exists only at variant level.

### variants

```sql
create table variants (
  id            uuid primary key default gen_random_uuid(),
  product_id    uuid not null references products(id) on delete restrict,
  variant_code  text not null,                     -- 'NVY-L'
  sku           text not null unique,              -- 'KMJ-OXF-NVY-L'
  color         text not null,
  size          text not null,
  price         numeric(12,2) not null,
  photo_path    text,
  current_stock int  not null default 0,           -- a CACHE, see below
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (product_id, variant_code)
);
```

**No `barcode` column.** The barcode is Code 128 containing the SKU itself, so there is no separate number to store. The image is generated at print time by `bwip-js` from the `sku` value.

`current_stock` is a **cache** for fast reads. It may only be changed inside the same transaction that writes the history row.

Variants with `is_active = false` are hidden from Stock In search, Manual Stock Out search, and the barcode list. They still appear in Product Detail (marked) and in Stock Audit, because the goods may still be on the shelf.

### stock_movements

The most important table. Every stock change, from any source, writes one row here.

```sql
create table stock_movements (
  id                   uuid primary key default gen_random_uuid(),
  variant_id           uuid not null references variants(id) on delete restrict,
  occurred_at          timestamptz not null default now(),
  stock_before         int  not null,
  change               int  not null,               -- + in, − out
  stock_after          int  not null,
  activity             movement_type not null,
  source               text not null,               -- 'Manual' | 'Shopee' | 'Audit Stok' | ...
  user_id              uuid references profiles(id), -- null = done by the system
  marketplace_order_id uuid references marketplace_orders(id)
);

create index idx_movements_variant on stock_movements (variant_id, occurred_at desc);
create index idx_movements_recent  on stock_movements (occurred_at desc);
```

Storing both `stock_before` and `stock_after` is technically redundant — both could be calculated. It is deliberate: the Stock History table shows all three, and it makes the audit trail readable without recomputing the whole chain.

**No UPDATE or DELETE on this table, ever.** Enforce it in the policy: allow `select` and `insert` only.

### marketplace_connections

```sql
create table marketplace_connections (
  id             uuid primary key default gen_random_uuid(),
  channel        channel_name not null unique,
  shop_name      text,
  is_connected   boolean not null default false,
  last_synced_at timestamptz,
  credentials    jsonb                            -- API tokens. NEVER send to the client
);
```

`credentials` must be blocked from the client by policy — readable only by the service role.

### marketplace_orders

```sql
create table marketplace_orders (
  id              uuid primary key default gen_random_uuid(),
  channel         channel_name not null,
  invoice_no      text not null,
  variant_id      uuid not null references variants(id),
  quantity        int  not null,
  status          order_status not null,
  stock_deducted  boolean not null default false,  -- the guard, see below
  ordered_at      timestamptz,
  synced_at       timestamptz not null default now(),
  unique (channel, invoice_no, variant_id)
);
```

`stock_deducted` matters: the sync job runs every 3 minutes and **will see the same order many times**. Without this guard, stock gets deducted over and over for one sale.

### The function every stock change goes through

```sql
create or replace function record_stock_movement(
  p_variant_id     uuid,
  p_change         int,
  p_activity       movement_type,
  p_source         text,
  p_user_id        uuid,
  p_expected_stock int
) returns stock_movements as $$
declare
  v_before int;
  v_after  int;
  v_row    stock_movements;
begin
  -- 1. lock the row
  select current_stock into v_before
    from variants where id = p_variant_id
    for update;

  -- 2. has it changed since the page was opened?
  if v_before <> p_expected_stock then
    raise exception 'STOCK_CHANGED:%:%', p_expected_stock, v_before;
  end if;

  v_after := v_before + p_change;
  if v_after < 0 then
    raise exception 'NEGATIVE_STOCK';
  end if;

  -- 3. write the history
  insert into stock_movements
    (variant_id, stock_before, change, stock_after, activity, source, user_id)
  values
    (p_variant_id, v_before, p_change, v_after, p_activity, p_source, p_user_id)
  returning * into v_row;

  -- 4. update the cache
  update variants set current_stock = v_after, updated_at = now()
   where id = p_variant_id;

  return v_row;   -- 5. commit happens when the transaction ends
end;
$$ language plpgsql;
```

Writing it as a database function rather than a series of queries from the app means **no code path can forget to write the history**.

### Which values each source passes

| Source | `change` | `activity` | `source` | `user_id` |
|---|---|---|---|---|
| Stock In | positive | `stock_in` | `Manual` | the person |
| Manual Stock Out | negative | `stock_out` | `Manual` | the person |
| Stock Audit | physical − system | `adjustment` | `Audit Stok` | the person |
| Order → processing | negative | `stock_out` | channel name | `null` |
| Order cancelled | positive | `order_cancelled` | channel name | `null` |

If the audit difference is zero, **write nothing at all**.

### Row Level Security

Turn RLS on for every table. The role is read from a custom claim in the JWT, filled from `profiles.role`.

| Table | Owner | Manager | Admin |
|---|---|---|---|
| `profiles` | select, insert, update | select self | select self |
| `categories` | all | all | all |
| `products`, `variants` | all | select | select |
| `stock_movements` | select, insert | select, insert | select, insert (except manual stock out) |
| `marketplace_connections` | select, update | select | select |
| `marketplace_orders` | select | select | select |

The two restrictions that are only a hidden tab on screen and must be real here:

```sql
-- Admin may not record manual stock out. Manager may.
create policy "manual stock out" on stock_movements for insert
  with check (
    not (activity = 'stock_out' and source = 'Manual'
         and (auth.jwt() ->> 'role') = 'admin')
  );

-- Only Owner may write products and variants
create policy "manage products" on products for all
  using ((auth.jwt() ->> 'role') = 'owner');
```

The marketplace sync writes with the service role, which bypasses RLS.

### Seed data

Use the same names and SKUs as the design, so the result is easy to compare.

| Product | Parent SKU | Category |
|---|---|---|
| Kemeja Oxford Lengan Panjang | `KMJ-OXF` | Kemeja |
| Kaos Katun Combed 30s | `KAO-CMB` | Kaos |
| Celana Chino Slim Fit | `CLN-CHN` | Celana |
| Dress Midi Linen | `DRS-MDL` | Dress |
| Blazer Formal Wanita | `BLZ-FRM` | Outerwear |
| Hoodie Fleece Oversize | `HDE-FLC` | Outerwear |
| Rok Plisket Midi | `ROK-PLS` | Rok |
| Jaket Denim Washed | `JKT-DNM` | Outerwear |

Variant code pattern: `[COLOR 3 letters]-[SIZE]` — `NVY-L`, `HTM-M`, `KRM-32`, `PTH-XL`.

The owner account is created by the seed script, with the password read from an environment variable — **never written in code**.

### Decide this before you freeze the schema

Adding a column later is possible, but old rows stay empty forever. So think now: is there anything you want recorded on **every stock movement** that is not in the list already?

Already there: time, variant, before, change, after, activity, source, user.

Candidates that usually show up too late: **shelf location**, **reason for an audit adjustment**, **reference document number**. If any of those might be needed, add them now — free today, a permanent hole in your history a year from now.

### Full stock take (opname) — deliberately deferred

Stock Audit is a *cycle count*: pick a few variants, count them, save, done immediately. That is right for counting shelf by shelf while the shop stays open.

A full monthly stock take is a different thing and needs four extra pieces: a **session** with states (open → counting → closed) so counts are not applied until the owner closes it, a **freeze period** that locks Stock In and Manual Stock Out, a **count sheet** showing which variants have not been counted yet, and a **summary screen** before closing.

Deferring it is genuinely cheap: two new tables plus one nullable column, nothing touching existing data. But put a comment in your migration so the decision reads as deliberate later:

```sql
-- Stock Audit = cycle count, applied immediately.
-- Full monthly stock take (session + freeze period) comes later;
-- will add stock_takes, stock_take_lines,
-- and stock_movements.stock_take_id (nullable).
```

One practical warning: if the shop already plans to close for a full count at month end, build this right after Week 3 — not months later.

---

## 7. Relationship diagram

```
                        ┌──────────────────┐
                        │   auth.users     │  (managed by Supabase)
                        └────────┬─────────┘
                                 │ 1:1
                                 ▼
                        ┌──────────────────┐
                        │    profiles      │
                        ├──────────────────┤
                        │ id          PK   │
                        │ name             │
                        │ role       enum  │  owner | manager | admin
                        │ is_active  bool  │
                        └────────┬─────────┘
                                 │
                                 │ who did it (nullable)
                                 │
┌──────────────────┐             │
│   categories     │             │
├──────────────────┤             │
│ id          PK   │             │
│ name      unique │             │
└────────┬─────────┘             │
         │ 1                     │
         │                       │
         │ has many              │
         ▼ N                     │
┌──────────────────┐             │
│    products      │             │
├──────────────────┤             │
│ id          PK   │             │
│ name             │             │
│ parent_sku  uniq │  KMJ-OXF    │
│ category_id FK   │             │
│ low_stock_thresh │             │
└────────┬─────────┘             │
         │ 1                     │
         │                       │
         │ has many              │
         ▼ N                     │
┌──────────────────┐             │
│    variants      │             │
├──────────────────┤             │
│ id          PK   │             │
│ product_id  FK   │             │
│ variant_code     │  NVY-L      │
│ sku         uniq │  KMJ-OXF-NVY-L   ← the barcode contains this
│ color, size      │             │
│ price            │             │
│ current_stock    │  ← CACHE only     │
│ is_active   bool │             │
└────┬─────────┬───┘             │
     │ 1       │ 1               │
     │         │                 │
     │ has     │ ordered in      │
     ▼ N       ▼ N               │
┌─────────────────────┐   ┌──────────────────────┐
│  stock_movements    │◄──┤ marketplace_orders   │
├─────────────────────┤   ├──────────────────────┤
│ id             PK   │   │ id              PK   │
│ variant_id     FK   │   │ channel       enum   │
│ occurred_at         │   │ invoice_no           │
│ stock_before   int  │   │ variant_id      FK   │
│ change         int  │   │ quantity        int  │
│ stock_after    int  │   │ status        enum   │
│ activity      enum  │   │ stock_deducted bool  │  ← the guard
│ source        text  │   └──────────────────────┘
│ user_id        FK ──┼───────────┘
│ mkt_order_id   FK   │
└─────────────────────┘
   APPEND ONLY
   never UPDATE, never DELETE


┌───────────────────────────┐
│ marketplace_connections   │   (standalone — 3 rows, one per channel)
├───────────────────────────┤
│ id                   PK   │
│ channel      enum  unique │  shopee | tokopedia | tiktok_shop
│ shop_name                 │
│ is_connected        bool  │
│ last_synced_at            │
│ credentials        jsonb  │  ← never send to the client
└───────────────────────────┘
```

Read it as one sentence: **a category has products, a product has variants, and a variant has a history of movements — some of which came from marketplace orders, and some of which a person made.**

---

## 8. Project file tree

```
kanona/
├── .env.local                        # secrets — MUST be in .gitignore
├── .gitignore
├── next.config.js
├── tailwind.config.ts
├── tsconfig.json
├── package.json
│
├── supabase/
│   ├── migrations/
│   │   ├── 0001_enums.sql
│   │   ├── 0002_profiles.sql
│   │   ├── 0003_categories_products_variants.sql
│   │   ├── 0004_stock_movements.sql
│   │   ├── 0005_marketplace.sql
│   │   ├── 0006_record_stock_movement.sql       # the function
│   │   └── 0007_rls_policies.sql
│   ├── functions/
│   │   └── sync-marketplace/
│   │       └── index.ts                          # runs every 3 min
│   └── seed.ts                                   # owner account + sample products
│
├── src/
│   ├── app/
│   │   ├── layout.tsx                            # html shell, fonts
│   │   ├── globals.css
│   │   ├── login/
│   │   │   └── page.tsx
│   │   └── (app)/                                # everything behind login
│   │       ├── layout.tsx                        # navbar + sidebar
│   │       ├── page.tsx                          # Dashboard
│   │       ├── produk/
│   │       │   ├── page.tsx                      # product list
│   │       │   └── [id]/page.tsx                 # product detail
│   │       ├── stok-masuk/page.tsx
│   │       ├── stok-keluar/page.tsx
│   │       ├── audit-stok/page.tsx
│   │       ├── riwayat-stok/page.tsx
│   │       ├── barcode/
│   │       │   ├── page.tsx
│   │       │   └── cetak/page.tsx                # print settings
│   │       ├── marketplace/page.tsx
│   │       └── pengaturan/page.tsx               # tabs: users, categories
│   │
│   ├── components/
│   │   ├── ui/                                   # shadcn: button, input, dialog…
│   │   ├── layout/
│   │   │   ├── Navbar.tsx
│   │   │   ├── Sidebar.tsx
│   │   │   └── ProfileMenu.tsx
│   │   ├── shared/
│   │   │   ├── DataTable.tsx                     # header + rows + sticky
│   │   │   ├── StatCard.tsx
│   │   │   ├── StatusChip.tsx
│   │   │   ├── EmptyState.tsx
│   │   │   ├── TableSkeleton.tsx
│   │   │   ├── Toast.tsx
│   │   │   └── VariantPicker.tsx                 # the 2-panel picker, reused 3×
│   │   ├── products/
│   │   │   ├── ProductTable.tsx
│   │   │   ├── ProductFormDialog.tsx
│   │   │   ├── VariantTable.tsx
│   │   │   ├── VariantFormDialog.tsx
│   │   │   └── VariantPreviewDialog.tsx
│   │   ├── stock/
│   │   │   ├── ScanInput.tsx
│   │   │   ├── StockInPanel.tsx
│   │   │   └── AuditPanel.tsx
│   │   ├── barcode/
│   │   │   ├── BarcodeGroupList.tsx
│   │   │   └── LabelPreview.tsx
│   │   └── settings/
│   │       ├── UserTable.tsx
│   │       ├── UserFormDialog.tsx
│   │       └── CategoryTable.tsx
│   │
│   ├── actions/                                  # server actions — all writes
│   │   ├── products.ts
│   │   ├── variants.ts
│   │   ├── stock.ts                              # in / out / audit
│   │   ├── users.ts
│   │   └── categories.ts
│   │
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts                         # browser
│   │   │   ├── server.ts                         # server components
│   │   │   └── admin.ts                          # service role — server only!
│   │   ├── permissions.ts                        # the ONE permission list
│   │   ├── barcode.ts                            # bwip-js wrapper
│   │   ├── format.ts                             # rupiah, dates
│   │   └── validation.ts                         # zod schemas
│   │
│   ├── hooks/
│   │   ├── useBarcodeScanner.ts
│   │   ├── useDebounce.ts
│   │   └── useRole.ts
│   │
│   └── types/
│       └── database.ts                           # generated by Supabase CLI
│
└── docs/
    ├── README.md                                 # this file
    ├── AGENTS.md
    └── kanona-ui-template.html                   # the design reference
```

---

## 9. React hooks you need

Because Next.js fetches data on the server, you need fewer hooks than you would expect. Hooks are only for the interactive parts.

| Hook | Used for |
|---|---|
| `useState` | form fields, dialog open/closed, selected variant, active tab, filter chips |
| `useRef` | keeping focus in the scan field; blocking a double-click on Save |
| `useMemo` | stock after saving, audit difference, total labels selected, filtering a list |
| `useEffect` | returning scanner focus, debouncing search. **Use sparingly** |
| `useActionState` | form submit + validation errors from the server ("SKU already used") |
| `useTransition` | pending state while navigating or saving |
| `useContext` | the signed-in user's role, read in many places |

**Do not use `useOptimistic` for stock numbers.** Showing a new stock figure before the server confirms is exactly wrong here — the server is the thing that checks. Fine for something light like ticking a barcode checkbox.

### Custom hooks worth writing

```ts
// useBarcodeScanner — a USB scanner behaves like a keyboard:
// fast keystrokes ending in Enter. Used on 3 pages.
function useBarcodeScanner(onScan: (code: string) => void) {
  const buffer = useRef('');
  const lastKey = useRef(0);

  useEffect(() => {
    function handle(e: KeyboardEvent) {
      const now = Date.now();
      if (now - lastKey.current > 100) buffer.current = '';  // human typing
      lastKey.current = now;

      if (e.key === 'Enter' && buffer.current.length > 3) {
        onScan(buffer.current);
        buffer.current = '';
      } else if (e.key.length === 1) {
        buffer.current += e.key;
      }
    }
    window.addEventListener('keydown', handle);
    return () => window.removeEventListener('keydown', handle);
  }, [onScan]);
}
```

```ts
// useDebounce — wait ~300ms before searching
function useDebounce<T>(value: T, delay = 300): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}
```

From libraries: `useForm` (only if you add react-hook-form later). TanStack Query is not needed — Server Components and Server Actions cover it.

---

## 10. Design tokens

### Core colours

| Name | Hex | Use |
|---|---|---|
| Primary | `#2563EB` | primary buttons, active menu, links |
| Primary hover | `#1D4ED8` | primary button hover |
| Success | `#22C55E` | success toast icon |
| Danger | `#EF4444` | delete button, required marker |
| Warning | `#F59E0B` | low stock icon |
| Background | `#F8FAFC` | content area |
| Card / Sidebar | `#FFFFFF` | cards, navbar, sidebar |
| Border | `#E5E7EB` | every border |
| Text primary | `#111827` | main text |
| Text secondary | `#6B7280` | helper text, table headers |

No gradients. No coloured backgrounds.

### Derived colours

| Role | Background | Text | Border |
|---|---|---|---|
| Blue chip / active menu | `#EFF6FF` | `#1D4ED8` | `#BFDBFE` |
| Success chip | `#ECFDF5` | `#15803D` | `#BBF7D0` |
| Danger chip / Out of stock | `#FEF2F2` | `#B91C1C` | `#FECACA` |
| Warning chip / Low stock | `#FFFBEB` | `#B45309` | `#FDE68A` |
| Neutral chip | `#F3F4F6` | `#374151` | — |
| Table row divider | `#F1F5F9` | — | — |
| Table row hover | `#F8FAFC` | — | — |
| Input placeholder | `#9CA3AF` | — | — |
| Empty state illustration | `#CBD5E1` | — | — |
| Modal overlay | `rgba(17,24,39,.45)` | — | — |

### Type

**Inter**, fallback system-ui. Weights 400, 500, 600, 700.

| Element | Size | Weight |
|---|---|---|
| Page title | 32px | 700 (letter-spacing −0.02em) |
| Card title | 18px | 600 |
| Stat number | 30px | 700 |
| Table header | 14px | 500 (`#6B7280`) |
| Body | 14px | 400 |
| Caption | 12px | 400 |

SKUs, barcodes, and invoice numbers always use monospace at 13px, so characters are easy to compare against a physical label.

### Spacing (8px system)

| Thing | Value |
|---|---|
| Page padding | 32px |
| Card padding | 24px |
| Gap between cards | 24px |
| Navbar height | 72px |
| Sidebar width | 250px (collapsed 76px) |
| Input height | 44px |
| Button height | 40px |
| Table row height | 52px |
| Border radius | 10px (modal 12px, button 8px) |
| Modal width | 600px (small 460px) |

### Shadows and motion

Three shadows only: dropdown `0 8px 24px rgba(17,24,39,.10)`, modal `0 20px 50px rgba(17,24,39,.2)`, toast `0 8px 24px rgba(17,24,39,.12)`. Cards and tables have **no shadow** — a 1px border only.

Two animations only: modal in (160ms), toast in (180ms). Skeleton pulse 1.4s.

### Icons

**Lucide**, outline, 20px, stroke-width 1.7. No filled icons. Use `lucide-react`.

---

## 11. The 12 screens

Every label is in **Bahasa Indonesia**. Variable names and code comments can be English.

| # | Screen | What it does |
|---|---|---|
| 1 | **Masuk** | login. No sign-up link — accounts are created inside the system |
| 2 | **Dashboard** | 6 stat cards, Recent Activity table, Needs Attention table with 2 filter chips (Habis, Menipis). Read only — nothing here changes stock |
| 3 | **Produk** | table with search, category filter, sort, Reset Filter. Scroll, not pagination |
| 4 | **Detail Produk** | product summary + variant table. Inactive variants are greyed with a "Nonaktif" chip |
| 5 | **Stok Masuk** | two panels: all variants left, selected variant right. Scan or search |
| 6 | **Stok Keluar** | two tabs. Marketplace (read only), Manual (same 2-panel layout). Admin does not see the Manual tab |
| 7 | **Audit Stok** | system stock vs physical stock, difference calculated and colour-coded |
| 8 | **Riwayat Stok** | 10 columns, 5 filters, date range as two `<input type="date">`. Never edited |
| 9 | **Barcode** | grouped by product, collapsible. Grouping is right here because printing labels is per-product work |
| 10 | **Pengaturan Cetak** | label contents as checkboxes that change the preview live, paper format |
| 11 | **Marketplace** | 3 connection cards. Reconnect button, disabled when connected. No manual sync button |
| 12 | **Pengaturan** | tabs: Pengguna (Owner only), Kategori |

### Dialogs

| Dialog | Width | Notes |
|---|---|---|
| Buat / Edit Produk | 600px | name, parent SKU, category, low stock threshold, photo |
| Tambah / Edit Varian | 600px | **fixed SKU prefix** + editable variant code, live full SKU below |
| Pratinjau Varian | 440px | large photo, barcode + SKU, then Colour · Size · Price in one row |
| Konfirmasi Hapus | 460px | "Riwayat stok yang sudah tercatat tetap tersimpan." |
| Tambah / Edit Pengguna | 600px | add mode: initial password. Edit mode: Active/Inactive toggle |
| Tambah / Edit Kategori | 460px | one field |
| Ubah Kata Sandi | 460px | Owner only, from the lock icon on the Owner row |
| Atur Ulang Kata Sandi | 460px | Owner only, for a staff row |

### Terms not to translate or rename

Stok Masuk · Stok Keluar · Audit Stok · Riwayat Stok · SKU Induk · Kode Varian · Stok Sistem · Stok Fisik · Selisih · Perlu Perhatian · Sinkron Terakhir · Reset Filter · Hubungkan Ulang

Role names: **Owner**, **Manager**, **Admin**. Never "Supervisor" or "Staff" — those are old names.

---

## 12. The 3-week build plan

You have three weeks, no prior experience, and you are working alone. That is tight but possible **if** you accept one thing: the marketplace integration will not be finished in three weeks, and it does not need to be. A shop can use this system without it.

So the plan aims at a working system in three weeks, with marketplace as week four onwards.

**Do this today, before you write any code:** register your app with Shopee Open Platform, Tokopedia Seller API, and TikTok Shop Partner Center. Partner approval can take weeks and runs in parallel with everything else. The most common mistake is finishing the code and discovering the permission has not come through.

### Week 1 — Foundation and Products

**Day 1–2 · Database.** All migrations, the `record_stock_movement` function, RLS policies. Test it from the Supabase SQL editor: call the function and watch stock change with a history row appearing.

*Understand before moving on:* why `stock_movements` is append-only, and why `variants.current_stock` is only a cache.

**Day 3 · Project setup and login.** Next.js, Tailwind, shadcn. The login page. The seed script for the owner account. **Check `.env.local` is in `.gitignore` before your first commit.**

**Day 4 · App shell.** Navbar, sidebar, profile menu, role context, the permission list.

*Done when:* changing the role in the database changes which menu items and buttons appear.

**Day 5–7 · Products and Variants.** Product table with search and filters, Product Detail, and four dialogs: Product form, Variant form, Variant preview, Delete confirm. Photo upload to Storage.

*Easy to get wrong:* the non-editable SKU prefix, and `stopPropagation()` on the row action icons so clicking the pencil does not also open the detail page.

### Week 2 — Stock movement

**Day 8–10 · Stok Masuk.** The most important days of the whole project. This is where the stock transaction gets built, and Stock Out and Audit later just copy the pattern. Get it wrong here and it is wrong everywhere.

Two-panel layout, the scan input, `useBarcodeScanner`, the "stock after saving" calculation, and saving through `record_stock_movement` with the `expected_stock` check.

*Test it properly before moving on:* open two browser tabs, change stock in one, then try to save from the other. You must get an error, not an overwrite.

**Day 11 · Riwayat Stok.** Fast, because the data is already being written. It also proves the audit trail is correct. Ten columns, sticky header, five filters. Store the date range in `sessionStorage` — it survives navigating away and back, and resets to the last 7 days when the tab closes.

**Day 12–13 · Stok Keluar manual and Audit Stok.** Quick now, because the pattern is already built. Hide the Manual tab from Admin in the UI **and** in RLS.

*Remember:* a zero difference in the audit writes no row at all.

**Day 14 · Dashboard.** Deliberately late — it only reads and aggregates data that now exists. Six stat cards, Recent Activity, Needs Attention with two filter chips.

**The system is usable by a real shop from here.**

### Week 3 — Barcode, Settings, polish

**Day 15–17 · Barcode and Print Settings.** Collapsible product groups with aligned checkboxes, print quantity per variant, the label content checkboxes that drive the preview, `bwip-js` generating Code 128 from the SKU, print CSS at label size.

*Test on a real printer early* — label sizes on screen often do not match what comes out.

**Day 18–19 · Settings.** Users tab (Owner only) and Categories tab, with their dialogs. Change Password and Reset Password.

**Day 20–21 · Test everything as all three roles.** Not just as Owner. This is where hidden-tab bugs surface. Then upgrade Supabase to Pro, and **test restoring a backup** — a backup you have never restored often cannot be restored.

### Week 4 onwards — Marketplace

Three connection cards, the OAuth flow per channel, the Edge Function that pulls orders, the `pg_cron` schedule every 3 minutes, order writing with the `stock_deducted` guard, cancellation handling, and the Marketplace tab in Stok Keluar.

*Understand:* why a scheduled pull needs an idempotent guard — the same function will see the same order many times.

### If you fall behind

Cut in this order: Print Settings page (print with defaults), the Barcode page (print from Product Detail one at a time), the Dashboard (staff can work without it). 

Do **not** cut: the `expected_stock` check, the append-only history, or the RLS policies. Those are the parts that keep the numbers true, and adding them later means auditing every write path you already built.

---

## 13. Rules you must not break

**Stock history is append-only.** Rows in `stock_movements` are never updated or deleted. Corrections are new rows. This is the system's only audit trail.

**Every stock change is atomic.** Change the stock and write the history row in one transaction. Never one without the other.

**Current stock is a result of the history**, not an independent number.

**Role restrictions live in the server and in RLS**, not only hidden in the UI.

**Ask about capability, not job title.** Components ask `can(role, 'manageProducts')`, never `role === 'owner'`.

**Store at the finest grain.** Stock moves per variant, never per product. The display may summarise; the storage may not.

**Passwords never live in code.** The owner's initial password is read from an environment variable by the seed script, hashed, and only the hash reaches the database. `.env.local` goes in `.gitignore` before the first commit.

**Users are not deleted.** Staff who leave are deactivated, because their name is still referenced by history rows.
