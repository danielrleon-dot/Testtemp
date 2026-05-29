# Personal CRM — Build Plan

> A personal relationship manager where **Claude is the primary interface on every
> device**, your **data lives online in your own Google Drive**, and a
> **purpose-built computer app** gives you a rich view for organizing and
> retrieving everything.

Last updated: 2026-05-29

---

## 1. Goals & constraints (from you)

- **Talk to Claude anywhere** — iPhone, iPad, MacBook, Windows — to capture and
  retrieve relationship data.
- **A purpose-built app on a computer** to organize/retrieve the data, with
  Claude's help.
- **Data stored online and accessible by Claude**, so anything you tell Claude on
  your phone gets pushed into your storage and organized.
- First-version features (all in scope for v1): **Contacts & profiles**,
  **Interaction log**, **Reminders & follow-ups**, **Search & timeline**.
- Stack/hosting: *"you choose for me"* → recommendations below with tradeoffs.

---

## 2. Architecture at a glance

```
        ┌──────────── You, on any device ────────────┐
        │  iPhone · iPad · MacBook · Windows PC       │
        └───────────────────┬─────────────────────────┘
                            │ talk / type
                            ▼
                  ┌───────────────────┐
                  │      CLAUDE       │  (Claude apps + connectors)
                  │  universal UI     │
                  └─────────┬─────────┘
        reads/writes files  │  creates reminders / reads email
            ┌───────────────┼────────────────┐
            ▼               ▼                 ▼
   ┌────────────────┐ ┌───────────┐   ┌──────────────┐
   │  GOOGLE DRIVE  │ │  GMAIL    │   │  GOOGLE CAL  │
   │  source of     │ │ enrich    │   │  follow-up   │
   │  truth (.md)   │ │ log       │   │  reminders   │
   └───────┬────────┘ └───────────┘   └──────────────┘
           │ sync (read + write back)
           ▼
   ┌──────────────────────────────┐
   │  PURPOSE-BUILT COMPUTER APP   │  contacts · timeline ·
   │  (local-first, Mac + Windows) │  search · reminders dashboard
   └──────────────────────────────┘
```

**Why Google Drive as the backbone (the "you choose for me" call):**

| Option | Verdict | Why |
|---|---|---|
| **Google Drive (chosen)** | ✅ v1 | Already connected to Claude in this environment; reachable from all your devices; free; private to your account; zero servers to run/maintain. |
| Custom hosted DB + MCP server | Later/optional | Most flexible, but you'd build + host + secure a server and wire a connector into Claude on every device. Overkill for one person. Keep as a future upgrade path. |
| Fully local files only | ❌ | Breaks the "Claude on my iPhone" requirement — Claude can't reach files that only live on one machine. |

**Why local-first app (not a hosted web app):** your relationship data stays
private on your machine + your Drive, nothing extra to host, and it works
offline. It syncs through the same Drive files Claude uses, so the app and Claude
never fight over a separate database.

---

## 3. Data model (the contract everything shares)

Source of truth = **one Markdown file per contact** in Drive, with YAML
frontmatter for structured fields and Markdown body for notes/log. Markdown is
human-readable, Claude-native (easy to read and append safely), diff-friendly,
and trivially parsed by the app.

```
Google Drive/
└── PersonalCRM/
    ├── CRM_GUIDE.md          # instructions Claude reads to operate the CRM
    ├── config.yml           # tag taxonomy, default follow-up cadences
    ├── contacts/
    │   ├── jane-doe.md
    │   └── john-smith.md
    └── index/
        └── contacts-index.json   # generated cache for fast search/dashboards
```

**Contact file format:**

```markdown
---
id: jane-doe
name: Jane Doe
emails: [jane@example.com]
phones: ["+1-555-0100"]
company: Acme
role: VP Engineering
tags: [friend, climbing, sf]
relationship: friend          # friend | family | colleague | client | ...
follow_up_cadence_days: 90    # 0 = no automatic cadence
last_interaction: 2026-05-20
next_follow_up: 2026-08-18
created: 2026-01-10
updated: 2026-05-20
---

## About
Met at the SF climbing gym. Trail runner. Just moved into a VP role and hiring.

## Interactions
- 2026-05-20 — ☕ Coffee. Talked about her new role; she's hiring 2 staff eng.
- 2026-03-02 — 💬 Text. Birthday wishes.

## Follow-ups
- [ ] 2026-08-18 — Check in on her hiring; offer intro to Sam
```

**Rules of the contract** (encoded in `CRM_GUIDE.md` so Claude behaves
consistently everywhere):
- Interactions are **append-only**, newest first, always dated `YYYY-MM-DD`.
- Adding an interaction updates `last_interaction` and recomputes `next_follow_up`
  (= last_interaction + cadence) unless an explicit follow-up date is given.
- `id` is a slug of the name; never reused.
- The app and Claude both write the **same** format so either can edit a record.

---

## 4. How "Claude everywhere" works in practice

1. **Connect once per device**: enable the Google Drive (+ Gmail + Calendar)
   connectors in the Claude apps you use on iPhone, iPad, Mac, and Windows.
2. **`CRM_GUIDE.md`** lives in the Drive folder and tells Claude exactly how to:
   - find/create the right contact file, append an interaction, update dates,
   - create a Calendar reminder for a follow-up,
   - keep `contacts-index.json` fresh.
   You point Claude at it (or save it as a Claude Project's instructions) so every
   conversation behaves the same.
3. **Capture from your phone**: *"Had lunch with Jane, she's hiring, remind me to
   follow up in August."* → Claude appends the interaction to `jane-doe.md`, sets
   `next_follow_up`, and creates a Calendar event. This satisfies "my interaction
   on iPhone is pushed to my storage and organized."
4. **Retrieve anywhere**: *"Who haven't I talked to in 3 months?"* / *"Show my
   history with John."* → Claude reads the Drive files (or the index) and answers.

This means **the CRM is fully usable on day one through Claude alone** — the
computer app is the power-user layer added next.

---

## 5. The purpose-built computer app

**Recommended stack (cross-platform, low-friction):**
- **Next.js + TypeScript + React** UI, run locally; package as a desktop app with
  **Tauri** later for native Mac/Windows installers. (Start as a local web app —
  fastest to iterate — then wrap in Tauri once stable.)
- **SQLite** as a local read/search cache/index (fast timeline + full-text
  search); **Drive remains the source of truth**.
- **Google Drive API** for two-way sync (pull files → index in SQLite; write
  edits back to the same Markdown files).

**Screens:**
- **Contacts** — list/grid with tags, search, filters; create/edit profile.
- **Profile + Timeline** — full chronological interaction history per person.
- **Reminders dashboard** — "Due / overdue follow-ups" and "Haven't talked to in
  N days," derived from `next_follow_up` + cadences.
- **Global search** — across names, notes, and interactions (SQLite FTS).
- **Quick-add** — fast interaction logging.

Why this over alternatives: a local web app is the fastest path to a working UI on
both your Mac and Windows machines; SQLite gives instant search without a server;
Tauri later gives you clean native installers without rewriting the UI.

---

## 6. Integrations (Gmail + Calendar)

- **Calendar = reminders engine.** Follow-ups become real Calendar events, so they
  surface natively on iPhone/iPad/Mac/Windows. The app and Claude both create/update
  them; `next_follow_up` in the contact file mirrors the event.
- **Gmail = log enrichment.** On request, Claude searches your threads with a
  contact and summarizes them into the Interactions section (e.g. *"add my recent
  emails with Jane to her log"*). Optional later: a daily pass that drafts log
  entries from new email for your review.
- **Daily digest** (later): a "who to reach out to today" summary Claude can
  generate on demand or on a schedule.

---

## 7. Phased delivery

### Phase 0 — Foundations (data + guide)
- [ ] Finalize the data model in this repo (`/spec/data-model.md`).
- [ ] Write `CRM_GUIDE.md` (Claude's operating instructions) and `config.yml`.
- [ ] Create the `PersonalCRM/` folder structure in Drive; add 2–3 seed contacts.
- [ ] Enable Drive/Gmail/Calendar connectors in your Claude apps on each device.
- **Outcome:** structure exists; ready to use.

### Phase 1 — CRM via Claude only (no app yet) ⭐ earliest value
- [ ] Validate the full loop through Claude: add contact, log interaction, set
      follow-up (with Calendar event), search, and timeline recall — on phone + desktop.
- [ ] Tune `CRM_GUIDE.md` until Claude is reliable and consistent.
- **Outcome:** a working personal CRM you operate entirely by talking to Claude.

### Phase 2 — Purpose-built computer app
- [ ] Scaffold Next.js + TS app in this repo; Google Drive OAuth + sync.
- [ ] Build Contacts, Profile/Timeline, Search (SQLite FTS), Reminders dashboard.
- [ ] Two-way write-back to Drive Markdown (round-trip safe with Claude's edits).
- **Outcome:** rich UI for organizing/retrieving, sharing data with Claude.

### Phase 3 — Integrations & automation
- [ ] Calendar follow-up sync (create/update/complete).
- [ ] Gmail enrichment command; optional daily digest.
- **Outcome:** reminders on all devices; log fills itself with less effort.

### Phase 4 — Polish & resilience
- [ ] Package app with Tauri for native Mac + Windows installers.
- [ ] Dedupe/merge contacts, import existing contacts (CSV/Google Contacts).
- [ ] Drive version history relied on for backups; conflict handling.
- **Outcome:** durable, installable, low-maintenance.

---

## 8. Open decisions to confirm before Phase 0

1. **Storage account** — use your existing Google account's Drive for the
   `PersonalCRM/` folder? (Recommended.)
2. **Markdown-per-contact vs. a single JSON/DB file** — plan assumes Markdown for
   Claude-friendliness + readability. OK?
3. **Build the app in this repo** (`danielrleon-dot/testtemp`), or a fresh repo?
4. **Migration** — any existing contacts/spreadsheet to import in Phase 4?

---

## 9. Repository layout (target)

```
.
├── PLAN.md                  # this file
├── spec/
│   ├── data-model.md        # the canonical contact/interaction schema
│   └── crm-guide.md         # source for the Drive CRM_GUIDE.md
├── app/                     # Next.js + TS purpose-built app (Phase 2)
└── scripts/                 # Drive setup / seed / index generation
```

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Claude edits drift from the format | Strict `CRM_GUIDE.md` + a validator script; app normalizes on write. |
| Edit conflicts (Claude vs app) | Append-only interactions; Drive version history; last-write-wins on scalar fields with `updated` timestamps. |
| Privacy of relationship data | Stays in your own Drive; local-first app; no third-party server. |
| Connector availability on a device | Phase 1 keeps the system usable via Claude; app is additive, not required. |
| Lock-in to Google | Data is plain Markdown — portable to any store; backend is swappable behind the same data contract. |
```
