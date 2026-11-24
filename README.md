# Hallo Batam AI

**A bilingual, retrieval-grounded travel assistant for Batam, Indonesia.**

![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?logo=javascript&logoColor=black) ![TypeScript](https://img.shields.io/badge/TypeScript-3178C6?logo=typescript&logoColor=white) ![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?logo=supabase&logoColor=white) ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?logo=postgresql&logoColor=white)

[Project portfolio](PORTFOLIO.md) · [Architecture](docs/ARCHITECTURE.md) · [Database notes](docs/DATABASE.md)

## Overview

Travel information is often fragmented across destination listings, operators and other sources. Hallo Batam AI combines a destination catalog with an Indonesian/English conversational interface, allowing users to explore places, ask questions and request travel itineraries through text and voice.

The frontend uses native HTML, CSS and JavaScript. The server-side implementation retrieves verified tourism documents through Supabase PostgreSQL REST/RPC, validates generated answers against source evidence and can fall back to checked data when an AI request fails.

> Backend source is a snapshot from the integration branch, documented as Supabase Function v31 on November 11, 2026. This repository does not establish that this is the current live deployment. Database schema migrations are not yet included.

## Architecture

```mermaid
flowchart LR
    U[Traveler] --> F[Browser / Vercel]
    F -->|HTTPS / JSON or audio| E[Supabase Edge Function]
    E -->|REST / RPC| D[(PostgreSQL)]
    E -->|Generation / transcription| A[OpenAI API]
    E -->|Answer + sources| F
    F --> C[Destination catalog and images]
```

## Key features

- Indonesian and English travel chat, destination discovery and preferences.
- Verified-document retrieval, source-linked responses and itinerary constraints.
- Microphone capture, server-side audio transcription and browser speech synthesis.
- Opaque session tokens, rate limiting, request validation and conversation persistence.
- A curated catalog of 69 destinations, with 39 local and 30 remote photo references.
- Browser security headers, script integrity checks, Markdown sanitization and an explicit asset publication allowlist.

The retrieval code uses verified document queries and ranking. The historical database audit reported pgvector installed but no populated embeddings; active semantic vector search is not claimed.

## Technology stack

| Layer | Technologies |
| --- | --- |
| Frontend | HTML, CSS, JavaScript, Marked.js, DOMPurify, Web Audio API |
| Backend | TypeScript, Deno, Supabase Edge Functions |
| Data | Supabase PostgreSQL, REST and RPC |
| AI | OpenAI API, text generation and audio transcription |
| Build & delivery | Node.js, Vercel, GitHub Actions |

## Repository layout

```text
.
├── .github/workflows/verify.yml
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CODE_GUIDE.md
│   ├── DATABASE.md
│   ├── INTEGRATION_AUDIT.md
│   └── history/
├── supabase/
│   ├── config.toml
│   └── functions/chat/
│       ├── index.ts
│       └── deno.json
├── wisata_batam_project/
│   ├── assets/
│   │   ├── branding/
│   │   └── destinations/
│   ├── index.html
│   ├── build.cjs
│   ├── check-integrations.cjs
│   ├── vercel.json
│   └── *-photo-sources.json
├── .env.example
└── PORTFOLIO.md
```

## Getting started

Use Node.js 22, as configured in CI, and Git. No npm dependency installation is required for the checked-in build.

```bash
git clone https://github.com/fahmifaldi61-tech/wisatabatam.git
cd wisatabatam
node wisata_batam_project/check-integrations.cjs
node wisata_batam_project/build.cjs
```

Serve the generated frontend on port 8000. With Python 3 installed:

```bash
python -m http.server 8000 --directory wisata_batam_project/public
```

Open `http://localhost:8000`. The static server is for development; it does not reproduce Vercel's response headers. The browser's configured API targets a hosted service and requires service availability, allowed origins and valid sessions. Do not point tests at a production service without authorization.

### Backend configuration

See [environment template](.env.example) for names used in the Edge Function. Configure secrets only in an authorized server environment. The function expects existing PostgreSQL tables and RPCs described in [database notes](docs/DATABASE.md). A fresh end-to-end deployment cannot be reproduced from this repository alone until verified SQL migrations are supplied. Do not deploy this historical snapshot over a live function without comparing versions and testing in a separate environment.

### Verification

```bash
node wisata_batam_project/check-integrations.cjs
node wisata_batam_project/build.cjs
```

The checks validate repository contracts and the CSP/asset build, not live API availability, image licenses or end-to-end behavior.

### Deployment

Keep the Vercel root directory set to `wisata_batam_project`. The existing `vercel.json` runs `node build.cjs` and publishes `public/`. The build preserves existing public asset names. Supabase function deployment is separate; this repository cleanup does not deploy backend code or modify the database.

If inline JavaScript changes, review and update CSP with `node wisata_batam_project/build.cjs --update-csp` before running checks. Never weaken security headers merely to make a build pass.

## Product showcase

[INSERT SCREENSHOT / DEMO GIF HERE: homepage and destination catalog]

[INSERT SCREENSHOT / DEMO GIF HERE: bilingual chat response with linked sources and destination photos]

[INSERT SCREENSHOT / DEMO GIF HERE: voice transcription interface and itinerary response]

## Documentation and credits

- [Architecture](docs/ARCHITECTURE.md) and [code guide](docs/CODE_GUIDE.md)
- [Database contract and limitations](docs/DATABASE.md)
- [Historical integration audit](docs/INTEGRATION_AUDIT.md)
- [Photo source references](wisata_batam_project/destination-photo-sources.json) and [remote photo references](wisata_batam_project/remote-destination-photo-sources.json)
- [Earlier Django/Chroma RAG prototype](https://github.com/fahmifaldi61-tech/wisatabatam-backend.) — not part of the current frontend request path.

Photo source attribution does not by itself establish redistribution rights; verify usage rights before republishing.
