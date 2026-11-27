'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const code = fs.readFileSync(path.join(__dirname, '../supabase/functions/chat/index.ts'), 'utf8')
  .replace('export async function handler', 'async function handler')
  .replace('Deno.serve(handler);', 'return handler;');

const place = {
  id: 7, slug: 'pantai-nongsa', title: 'Pantai Nongsa', category: 'pantai',
  region: 'Nongsa', publisher: 'BP Batam', source_name: 'BP Batam', source_url: 'https://bpbatam.go.id/',
  checked_at: new Date().toISOString().slice(0, 10), lexical_score: 0.8, rrf_score: 1 / 61,
  chunk_text: 'Pantai Nongsa memiliki kawasan pesisir.\n\nParagraf lain.',
  facts: { summary: { id: 'Pantai Nongsa memiliki kawasan pesisir.', en: 'Nongsa Beach has a coastal area.' },
    location: { id: 'Nongsa, Batam', en: 'Nongsa, Batam' } }
};

function fixture({ cache = false, rewriteFails = false, modelFails = false, rows = [place], dbFails = false } = {}) {
  const network = [];
  const background = [];
  const session = '24c5475a-cbb4-4c32-b7b3-6862a37cc323';
  const config = {
    SUPABASE_URL: 'https://db.test', SUPABASE_SERVICE_ROLE_KEY: 'test-db-placeholder',
    OPENAI_API_KEY: 'test-provider-placeholder',
  };
  const handler = Function('Deno','EdgeRuntime','fetch',code)({env:{get:key=>config[key]}},
    {waitUntil:work=>background.push(work)},async (url, options) => {
      const u = new URL(url);
      const payload = options.body ? JSON.parse(options.body) : null;
      const route = u.pathname.split('/').at(-1);
      network.push({route, payload, method:options.method});
      const ok = object => Response.json(object);
      if (u.hostname === 'api.openai.com') {
        const rewrite = payload.max_output_tokens === 100;
        if (rewrite && rewriteFails) throw new Error('timeout');
        const text = rewrite ? 'pantai Nongsa' : modelFails ? 'malformed JSON'
          : JSON.stringify({intro:'',items:[{id:place.id,text:'Pantai ini memiliki kawasan pesisir.'}]});
        return ok({status:'completed', output:[{type:'message',content:[{type:'output_text',text}]}]});
      }
      if (route === 'hb_claim_session') return ok({id:session});
      if (route === 'hb_take_limit') return ok(true);
      if (route === 'hb_reserve_openai_request') return ok({allowed:true,model:'gpt-6-luna'});
      if (route === 'hb_rag_hybrid_search') return dbFails ? new Response('',{status:500}) : ok(rows);
      if (route === 'hb_rag_cache_get') return ok(cache ? {answer:'[1] Pantai Nongsa',response:'[1] Pantai Nongsa',
        sources:[{url:place.source_url}],citations:[{match_score:100}],followup_chips:[],evidence_gap:null} : null);
      if (route === 'hb_turns' || route === 'hb_documents') return ok([]);
      if (route === 'rag_telemetry_logs') return new Response('',{status:500});
      return new Response(null,{status:204});
    });
  return {network, async ask(message, filters = {}, language='id') {
    const response = await handler(new Request('https://edge.test/chat',{method:'POST',headers:{
      'Content-Type':'application/json',Authorization:'Bearer '+'a'.repeat(64)
    }, body:JSON.stringify({message,language,...filters})}));
    await Promise.all(background);
    assert.equal(response.status,200);
    return response.json();
  }};
}

test('filtered tourism answer keeps legacy response and attaches exact source evidence', async () => {
  const env=fixture();
  const result=await env.ask('Di mana lokasi Pantai Nongsa?',{area:'Nongsa',category:'Pantai'});
  assert.equal(result.answer,result.response);
  assert.match(result.answer,/\[1\]/);
  assert.equal(result.citations[0].chunk_snippet,'Pantai Nongsa memiliki kawasan pesisir.');
  assert.equal(result.citations[0].source_url,place.source_url);
  assert.equal(result.followup_chips.length,2);
  const query=env.network.find(n=>n.route==='hb_rag_hybrid_search').payload;
  assert.equal(query.p_area,'nongsa');
  assert.deepEqual(query.p_categories,['pantai']);
  assert.equal(result.telemetry.cache_hit,false);
});
test('live crowd question reports evidence gap and skips all model calls', async () => {
  const env=fixture();
  const result=await env.ask('Seberapa ramai Pantai Nongsa sore ini?');
  assert.match(result.evidence_gap,/keramaian/);
  assert.match(result.response,/tidak memastikan/);
  assert.equal(env.network.some(n=>n.route==='responses'),false);
  assert.equal(env.network.some(n=>n.route==='hb_rag_cache_get'),false);
});
test('rewriter timeout and malformed generation fall back to raw checked evidence', async () => {
  const env=fixture({modelFails:true,rewriteFails:true});
  const query='Rekomendasi pantai sekitar Nongsa';
  const result=await env.ask(query);
  assert.equal(env.network.find(n=>n.route==='hb_rag_hybrid_search').payload.p_query,query);
  assert.match(result.response,/Pantai Nongsa/);
  assert.match(result.provider_used,/fallback/);
});
test('valid cached answer avoids model calls and still records the turn', async () => {
  const env=fixture({cache:true});
  const result=await env.ask('Di mana lokasi Pantai Nongsa?');
  assert.equal(result.telemetry.cache_hit,true);
  assert.equal(env.network.some(n=>n.route==='responses'),false);
  assert.equal(env.network.some(n=>n.route==='hb_finish_grounded_turn'),true);
});
test('failed retrieval with explicit filters fails closed in English', async () => {
  const env=fixture({dbFails:true});
  const result=await env.ask('Where is Nongsa Beach?',{area:'Sekupang'},'en');
  assert.match(result.evidence_gap,/selected filters/);
  assert.deepEqual(result.citations,[]);
  assert.equal(env.network.some(n=>n.route==='hb_discover_places'),false);
});
