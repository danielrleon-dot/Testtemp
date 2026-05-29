# Personal CRM — Build Plan

> A personal relationship manager where **Claude is the primary interface on every
> device**, backed by a **small custom service that Claude reads *and writes* via a
> Model Context Protocol (MCP) connector**, plus a **purpose-built computer app**
> for organizing and retrieving everything.

Last updated: 2026-05-29

---

## 0. Decisions locked in with you

1. **Claude cannot reliably *write* to Google Drive from your devices.** ✅ Correct.
   The consumer Google Drive connector in the Claude apps is **read-only
   retrieval**. So the write path is a **custom MCP backend** (below), not Drive.
   Drive is optional, used only as a read-only Markdown *mirror* for backup/portability.
2. **Data format:** Markdown-per-contact (human-readable, Claude-friendly, portable). ✅
3. **Code lives in a new, dedicated repo** (not `testtemp`). ⚠️ *Blocked in this
   session — see §8. This plan file is portable to the new repo.*
4. **More data sources are coming later.** ✅ The data model and backend are
   designed to be **source-pluggable** from day one (manual, email, calendar, and
   future importers all write the same interaction records).

---

## 1. Goals & constraints (from you)

- **Talk to Claude anywhere** — iPhone, iPad, MacBook, Windows — to capture and
  retrieve relationship data, with anything you say pushed into storage and organized.
- **A purpose-built app on a computer** to organize/retrieve the data.
- **Data online and accessible to Claude** for read *and* write.
- v1 features: **Contacts & profiles**, **Interaction log**, **Reminders &
  follow-ups**, **Search & timeline**.
- Stack/hosting: *"you choose for me"* → recommendations below.

---

## 2. Architecture at a glance

```
        ┌──────────── You, on any device ────────────┐
        │  iPhone · iPad · MacBook · Windows PC       │
        └───────────────────┬─────────────────────────┘
                            │ talk / type
                            ▼
                  ┌───────────────────┐
                  │      CLAUDE       │
                  │  universal UI     │
                  └─────────┬─────────┘
            custom MCP connector (READ + WRITE)
                            │
                            ▼
        ┌─────────────────────────────────────────────┐
        │            CRM BACKEND  (one service)         │
        │  ┌─────────────┐   ┌──────────────────────┐   │
        │  │ MCP endpoint│   │  Web UI (the app)    │   │
        │  │ for Claude  │   │  contacts/timeline/  │   │
        │  │             │   │  search/reminders    │   │
        │  └──────┬──────┘   └──────────┬───────────┘   │
        │         └──────────┬──────────┘               │
        │                    ▼                          │
        │        Database (SQLite/Postgres)             │
        │        + pluggable source importers           │
        └───────┬───────────────────────────┬───────────┘
                │ optional read-only mirror  │ enrich
                ▼                            ▼
        ┌──────────────┐            ┌─────────────────┐
        │ GOOGLE DRIVE │            │ GMAIL · CALENDAR│
        │ .md backup   │            │ sources         │
        └──────────────┘            └─────────────────┘
```

**The core change from the first draft:** the source of truth is now the
**backend's database**, exposed to Claude through an **MCP endpoint** (read +
write) and to you through the **web UI**. One service, two front doors. Drive
demotes to an optional read-only mirror.

**Storage / hosting — the "you choose for me" call:**

| Option | Verdict | Why |
|---|---|---|
| **Custom MCP backend + DB (chosen)** | ✅ v1 | Only dependable way for Claude to *write* from all your devices. One codebase serves both Claude (MCP) and the app (UI). |
| Google Drive as source of truth | ❌ | Consumer Drive connector is read-only; can't be the write path. |
| Local-only MCP server on your computer | ❌ for phone | Not reachable from your iPhone when the computer is off/away. |

**Where to run the one service (pick in §8):**
- **Cheap cloud** (Fly.io / Railway / Render, ~$0–5/mo): reachable from all devices
  anytime, minimal ops. *Recommended.*
- **Self-host on an always-on machine** + a tunnel (Cloudflare Tunnel/Tailscale):
  zero hosting cost, data fully yours, slightly more setup.

Both keep the data **private to you** (single-user, token-protected).

---

## 3. Data model (source-pluggable from day one)

Database tables (the canonical store). Markdown export mirrors these for backup.

**`contacts`**
`id` (slug) · `name` · `emails[]` · `phones[]` · `company` · `role` · `tags[]` ·
`relationship` · `follow_up_cadence_days` · `last_interaction` · `next_follow_up`
· `notes` (markdown) · `created` · `updated`

**`interactions`** (append-only, the heart of the log)
`id` · `contact_id` · `date` · `channel` (coffee/call/text/email/meeting/…) ·
`summary` · **`source`** (`manual` | `email` | `calendar` | `import:<name>` | …) ·
`source_ref` (e.g. Gmail thread id, so we can dedupe + link back) · `created`

**`followups`**
`id` · `contact_id` · `due_date` · `note` · `done` · `calendar_event_id`

The **`source` + `source_ref`** fields are what make new data sources easy: every
importer (email today, others later) just writes interaction rows tagged with its
origin, and dedupe keys off `source_ref`. Adding a source = adding one importer; no
schema change.

**Markdown mirror** (one file per contact in Drive/Git, generated): YAML
frontmatter for the scalar fields + a chronological `## Interactions` section.

---

## 4. How "Claude everywhere" works (revised)

1. **Add the backend as a custom MCP connector** in each Claude app (iPhone, iPad,
   Mac, Windows), authenticated with your personal token.
2. The backend exposes a tight set of MCP tools, e.g.:
   `find_contact`, `create_contact`, `log_interaction`, `set_followup`,
   `due_followups`, `search`, `get_timeline`.
3. **Capture from your phone:** *"Had lunch with Jane, she's hiring, follow up in
   August."* → Claude calls `log_interaction` + `set_followup`; the backend writes
   to the DB and creates a Calendar event. **Now this genuinely persists** —
   satisfying "pushed to my storage and organized."
4. **Retrieve anywhere:** *"Who am I overdue to contact?"* / *"History with John?"*
   → Claude calls `due_followups` / `get_timeline`.

Because the contract is MCP tools (not free-form file editing), Claude behaves
consistently on every device with far less room to corrupt data.

---

## 5. The purpose-built computer app

Same backend, web UI front door (run locally or open the hosted URL; package with
**Tauri** later for native Mac + Windows installers).

- **Stack:** Next.js + TypeScript + React; backend via Next.js API routes (or a
  small Fastify service) sharing the DB; **SQLite** to start (zero-ops), Postgres
  if you outgrow it.
- **Screens:** Contacts (search/filter by tag) · Profile + Timeline · Reminders
  dashboard (overdue / due-soon / "haven't talked to in N days") · Quick-add.
- **Search:** SQLite FTS across names, notes, and interaction summaries.

One repo builds one deployable that powers **both** the MCP endpoint and the UI.

---

## 6. Integrations & future sources

- **Calendar = reminders engine.** Follow-ups become Calendar events (mirrored via
  `followups.calendar_event_id`), surfacing natively on all your devices.
- **Gmail = first importer.** On request (or scheduled), pull threads with a
  contact, summarize into `interactions` tagged `source=email`, dedup by
  `source_ref`.
- **Future sources (your point #4):** each new source is a self-contained importer
  writing the same interaction rows — e.g. WhatsApp/iMessage exports, LinkedIn,
  CSV/Google Contacts, meeting-notes tools. No schema churn.

---

## 7. Phased delivery

### Phase 0 — Backend + data contract
- [ ] New repo scaffold; define DB schema + the MCP tool list (`spec/`).
- [ ] Implement the service: DB + CRUD + MCP endpoint with auth.
- [ ] Deploy to cheap cloud (or self-host + tunnel).

### Phase 1 — Claude on all devices ⭐ earliest value
- [ ] Add the MCP connector in each Claude app; verify add/log/followup/search/
      timeline from iPhone **and** desktop.
- **Outcome:** a working CRM you operate entirely by talking to Claude — with
  reliable writes.

### Phase 2 — Purpose-built app
- [ ] Web UI: Contacts, Profile/Timeline, Search, Reminders dashboard, Quick-add.
- [ ] Markdown export/mirror to Drive or Git for backup.

### Phase 3 — Integrations
- [ ] Calendar follow-up sync; Gmail importer; optional daily "who to reach out to"
      digest.

### Phase 4 — Polish & more sources
- [ ] Tauri native installers (Mac + Windows).
- [ ] Additional source importers; dedupe/merge; import existing contacts.

---

## 8. Open items before Phase 0

1. **New repo (blocker):** this session can't create/push to a repo other than
   `testtemp`. To proceed cleanly, **you** create `personal-crm` on GitHub, then
   either start a Claude Code session pointed at it, or grant this environment
   access. (Options also summarized in chat.)
2. **Hosting:** cheap cloud (recommended) vs. self-host + tunnel?
3. **Auth:** a single personal bearer token for the MCP connector is fine for a
   one-person tool — confirm.

---

## 9. Target repo layout

```
.
├── PLAN.md
├── spec/
│   ├── data-model.md     # DB schema + Markdown mirror format
│   └── mcp-tools.md      # the MCP tool contract Claude uses
├── server/               # backend: DB + API + MCP endpoint
├── app/                  # Next.js UI (Phase 2)
└── importers/            # pluggable source importers (Phase 3+)
```

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Running a server = ops/cost | One tiny single-user service; cheap-cloud free tiers or self-host; SQLite needs no DB server. |
| Custom MCP connector setup per device | One-time token paste; documented in repo README. |
| Duplicate interactions from importers | `source` + `source_ref` dedupe keys. |
| Data lock-in | Markdown mirror + plain SQL; backend swappable behind the MCP contract. |
| Privacy | Single-user, token-protected, your own host; no third-party SaaS holds the data. |
```
