-- Additive and server-only. Existing documents, RPCs, and clients remain valid.
alter table public.hb_documents
  add column if not exists rag_search_vector tsvector generated always as (
    setweight(to_tsvector('simple'::regconfig, coalesce(title, '') || ' ' || coalesce(aliases, '')), 'A')
    || setweight(to_tsvector('simple'::regconfig, coalesce(content, '') || ' ' || coalesce(content_en, '')), 'B')
  ) stored;

create index if not exists hb_documents_rag_search_gin
  on public.hb_documents using gin (rag_search_vector) where verified;

create table if not exists public.rag_semantic_cache (
  id bigint generated always as identity primary key,
  query_text text not null,
  filter_key text not null,
  query_embedding extensions.vector(768),
  embedding_model text,
  response_payload jsonb not null,
  hit_count integer not null default 1,
  created_at timestamptz not null default now(),
  unique (filter_key, query_text)
);

create table if not exists public.rag_telemetry_logs (
  id bigint generated always as identity primary key,
  query_text text not null,
  cache_hit boolean not null,
  retrieval_ms integer not null check (retrieval_ms >= 0),
  total_ms integer not null check (total_ms >= 0),
  top_score double precision,
  has_evidence_gap boolean not null,
  created_at timestamptz not null default now()
);

create index if not exists hb_rag_telemetry_created_idx
  on public.rag_telemetry_logs (created_at);

alter table public.rag_semantic_cache enable row level security;
alter table public.rag_telemetry_logs enable row level security;
revoke all on public.rag_semantic_cache, public.rag_telemetry_logs from public, anon, authenticated;
grant select, insert, update, delete on public.rag_semantic_cache to service_role;
grant insert, delete, select on public.rag_telemetry_logs to service_role;

create or replace function public.hb_rag_hybrid_search(
  p_query text, p_area text default null, p_categories text[] default null,
  p_embedding extensions.vector default null, p_embedding_model text default null,
  p_preferred_ids text[] default null
) returns table (
  id bigint, slug text, title text, category text, categories text[], region text,
  publisher text, source_url text, checked_at date, facts jsonb, aliases text,
  chunk_text text, source_name text, lexical_score real, similarity double precision, rrf_score double precision
) language sql stable security invoker set search_path = public, extensions, pg_temp as $$
  with tokens as (
    select to_tsquery('simple', string_agg(quote_literal(word), ' | ' order by word)) query
    from (
      select distinct word from regexp_split_to_table(lower(left(coalesce(p_query, ''), 400)), '[^[:alnum:]]+') word
      where length(word) >= 3 and word <> all (array[
        'apa','yang','dan','untuk','dengan','dari','ada','batam','this','the','what','where','can','you',
        'recommend','rekomen','rekomendasi','seberapa','ramai','crowded','ini','sore','today','now',
        'berapa','tetang','tentang','tolong','about','tell','please'
      ])
      order by word limit 24
    ) t
  ), candidates as (
    select d.* from public.hb_documents d
    where d.verified and d.checked_at >= current_date - 90
      and (p_categories is null or d.category = any(p_categories)
        or coalesce(d.categories, array[]::text[]) && p_categories)
      and (p_area is null or lower(d.region) = p_area or lower(d.facts #>> '{profile,area}') = p_area
        or lower(d.facts #>> '{profile,area}') like p_area || ' %'
        or (p_area = 'barelang' and concat_ws(' ', d.title, d.aliases, d.facts #>> '{profile,area}') ~* '\ybarelang\y'))
  ), sparse_top as (
    select d.id, case when d.rag_search_vector @@ t.query then ts_rank_cd(d.rag_search_vector, t.query, 32) else 0 end as relevance,
      coalesce(d.slug = any(p_preferred_ids), false) as preferred
    from candidates d cross join tokens t
    where d.rag_search_vector @@ t.query or d.slug = any(p_preferred_ids)
    order by preferred desc, relevance desc, d.id limit 24
  ), sparse as (
    select *, row_number() over (order by preferred desc, relevance desc, id) as rank from sparse_top
  ), dense_top as (
    select d.id, d.embedding <=> p_embedding as distance
    from candidates d
    where p_embedding is not null and p_embedding_model is not null
      and d.embedding is not null and d.embedding_model = p_embedding_model
    order by distance, d.id limit 24
  ), dense as (
    select *, row_number() over (order by distance, id) as rank from dense_top
  ), fused as (
    select coalesce(s.id, v.id) as id, s.relevance, 1 - v.distance as similarity,
      coalesce(1.0 / (60 + s.rank), 0)::double precision + coalesce(1.0 / (60 + v.rank), 0)::double precision as score
    from sparse s full join dense v using (id)
  )
  select d.id, d.slug, d.title, d.category, d.categories, d.region, d.publisher, d.source_url, d.checked_at,
    d.facts, d.aliases, coalesce(d.content, d.content_en, ''), coalesce(d.publisher, d.source), f.relevance,
    f.similarity, f.score
  from fused f join candidates d on d.id = f.id
  order by f.score desc, d.id limit 8;
$$;

create or replace function public.hb_rag_cache_get(
  p_query text, p_filter_key text, p_embedding extensions.vector default null,
  p_embedding_model text default null
) returns jsonb language sql volatile security invoker set search_path = public, extensions, pg_temp as $$
  update public.rag_semantic_cache c set hit_count = c.hit_count + 1
  where c.id = (
    select m.id from public.rag_semantic_cache m
    where m.filter_key = p_filter_key and m.created_at >= now() - interval '10 minutes'
      and (m.query_text = p_query or (p_embedding is not null and m.query_embedding is not null
        and p_embedding_model is not null and m.embedding_model = p_embedding_model
        and 1 - (m.query_embedding <=> p_embedding) >= .94))
      and jsonb_typeof(m.response_payload->'sources') = 'array'
      and jsonb_array_length(m.response_payload->'sources') > 0
      and not exists (
        select 1 from jsonb_array_elements(m.response_payload->'sources') s
        where not exists (
          select 1 from public.hb_documents d where d.id::text = s->>'document_id'
            and d.source_url = s->>'url' and d.checked_at::text = s->>'checked_at'
            and d.verified and d.checked_at >= current_date - 90
        )
      )
    order by (m.query_text = p_query) desc, m.query_embedding <=> p_embedding asc nulls last, m.created_at desc limit 1
  ) returning c.response_payload;
$$;

create or replace function public.hb_rag_prune() returns void
language sql volatile security invoker set search_path = public, pg_temp as $$
  delete from public.rag_semantic_cache where created_at < now() - interval '10 minutes';
  delete from public.rag_telemetry_logs where created_at < now() - interval '30 days';
$$;

revoke all on function public.hb_rag_hybrid_search(text,text,text[],extensions.vector,text,text[]) from public, anon, authenticated;
revoke all on function public.hb_rag_cache_get(text,text,extensions.vector,text) from public, anon, authenticated;
revoke all on function public.hb_rag_prune() from public, anon, authenticated;
grant execute on function public.hb_rag_hybrid_search(text,text,text[],extensions.vector,text,text[]) to service_role;
grant execute on function public.hb_rag_cache_get(text,text,extensions.vector,text) to service_role;
grant execute on function public.hb_rag_prune() to service_role;
