# Grounded retrieval and evidence

Apply the additive migration under `supabase/migrations/` before deploying this Edge Function. The browser can talk to either revision. The answer, sources, provider, locale, session and retrieval fields already used by the client remain available. The new chat response adds answer, citations, evidence_gap, followup_chips and telemetry. A retry served by the legacy per-request idempotency record can still return the original fields alone.

- Search indexes title, aliases and bilingual content. Explicit area and category are applied before each rank. Sparse and matching-model dense ranks are fused with reciprocal rank fusion (k = 60), capped at eight candidates, and reranked with known place identities and title terms.
- Today the verified corpus has no document embeddings, and the live application has no existing embedding client. The Edge Function uses the sparse path and does not request new OpenAI embedding calls. The SQL supports model-matched 768-dimensional pgvector inputs when an approved source of compatible embeddings exists. Its semantic cache checks cosine similarity of at least 0.94 when matching vectors are supplied. The active cache checks exact standalone named-place queries, scoped to session, language, selected filters and revision. The ten-minute cache rechecks source verification and freshness.
- Model generation uses the existing validated JSON item schema. The server builds citations from the accepted document IDs and uses actual PostgreSQL excerpts and URLs. Lexical relevance and exact place matches are labeled separately from hybrid scores. A malformed model result falls back to checked data. A live crowd or weather query gets an evidence gap and bypasses generation and cache.
- Telemetry is server-only, best effort and currently retained for thirty days by opportunistic pruning. It strips common email, number and long-token patterns. Latency values reflect the request actually observed rather than a guaranteed service level.

## Checks

```sh
node --test wisata_batam_project/check-rag.cjs
node wisata_batam_project/check-integrations.cjs
node wisata_batam_project/build.cjs
```
