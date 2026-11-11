// SymptomBridge API: a Cloudflare Worker that keeps the Gemini key secret.
//
// It does one job only: given a consultation transcript and the engine's
// list of clinical concepts, it asks Gemini which concepts were mentioned,
// by whom, and with which exact words. The prompt lives here, not in the
// browser, so the Worker cannot be used as a free general-purpose proxy.
//
// Setup (Cloudflare dashboard → the Worker):
//   Settings → Variables and Secrets → Secret GEMINI_API_KEY
//   optional Text MODEL (forces one model), ALLOWED_ORIGINS (comma separated)
// Nothing is stored or logged.
//
// Open the Worker's address with ?check in a browser to see which version is
// deployed, which model answers and how long it takes.

const VERSION = '2026-11-11b';

// Model names are retired over time, so use aliases and, if Google says one
// doesn't exist, pick a Flash model from the ones this key can use.
// Lite first: this is lookup, not reasoning, and it answers fastest.
const PREFERRED_MODELS = ['gemini-flash-lite-latest', 'gemini-flash-latest'];
const API = 'https://generativelanguage.googleapis.com/v1beta';
const DEFAULT_ORIGINS = 'https://margaridafpereira.github.io,http://localhost:8765';
const MAX_TRANSCRIPT = 6000; // characters, about ten minutes of speech
const MAX_CONCEPTS = 150;
const CALL_TIMEOUT_MS = 15000; // per model call; the app gives up after 40 s

// Newer Flash models "think" before answering, which can take tens of
// seconds. Ask for no thinking, in the two ways different models accept,
// and finally with no setting at all.
const THINKING_OPTIONS = [{ thinkingBudget: 0 }, { thinkingLevel: 'minimal' }, null];

const INSTRUCTIONS = `You read transcripts of medical consultations in European Portuguese.
Some lines start with "Médico:" (clinician) or "Doente:" (patient); lines without a label are the patient.

Find every concept from the CONCEPTS list that the transcript gives information about.
For each one return:
- "id": exactly one id from the CONCEPTS list. Never invent ids.
- "status": "present" if the patient has it, "absent" if the patient says they do not.
  A clinician's question answered yes or no by the patient counts. Vague answers like
  "às vezes" or "um bocadinho" mean present.
- "quote": the exact words from the transcript that show it, copied character for
  character, as short as possible (2 to 10 words). Never paraphrase.
- "who": "patient", or "other" when it is about someone else (for example a relative's
  illness: "o meu pai morreu de enfarte" is NOT the patient's heart disease).
- "when": "now", or "past" when the patient says it happened before and has gone.

Understand colloquial Portuguese ("moinha" = dull pain, "tripa solta" = diarrhoea,
"deitar tudo fora" = vomiting, "cara à banda" = face drooping), indirect statements
("era melhor não estar cá" = thoughts of suicide) and speech-recognition errors
("soares frios" = "suores frios").
Do not diagnose. Return only concepts actually supported by the transcript.

Answer only with JSON: {"findings": [ ... ]}`;

export default {
  async fetch(request, env) {
    const origins = (env.ALLOWED_ORIGINS || DEFAULT_ORIGINS).split(',').map((s) => s.trim());
    const origin = request.headers.get('Origin') || '';
    const cors = {
      'Access-Control-Allow-Origin': origins.includes(origin) ? origin : origins[0],
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Vary': 'Origin',
    };
    const reply = (status, body) =>
      new Response(JSON.stringify(body, null, 2), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    if (request.method === 'GET') return reply(200, await check(env, new URL(request.url)));
    if (request.method !== 'POST') return reply(405, { error: 'POST only' });
    // Browsers always send Origin; the evaluation script sends none.
    if (origin && !origins.includes(origin)) return reply(403, { error: 'origin not allowed' });
    if (!env.GEMINI_API_KEY) return reply(500, { error: 'GEMINI_API_KEY is not set' });

    let input;
    try {
      input = await request.json();
    } catch {
      return reply(400, { error: 'body must be JSON' });
    }
    const parsed = validate(input);
    if (parsed.error) return reply(parsed.status, { error: parsed.error });

    const result = await understand(env, parsed.list, parsed.transcript);
    return result.error ? reply(result.status, { error: result.error }) : reply(200, result);
  },
};

function validate(input) {
  const transcript = typeof input?.transcript === 'string' ? input.transcript : '';
  const concepts = Array.isArray(input?.concepts) ? input.concepts : [];
  if (!transcript.trim()) return { status: 400, error: 'transcript is empty' };
  if (transcript.length > MAX_TRANSCRIPT) return { status: 413, error: 'transcript too long' };
  if (concepts.length === 0 || concepts.length > MAX_CONCEPTS) return { status: 400, error: 'bad concept list' };
  const list = [];
  for (const c of concepts) {
    if (!c || !/^[a-z_]{2,40}$/.test(c.id) || typeof c.label !== 'string' || c.label.length > 100) {
      return { status: 400, error: 'bad concept' };
    }
    list.push(`${c.id}: ${c.label}`);
  }
  return { list, transcript };
}

/// Asks the models in turn. Returns {model, findings} or {status, error}.
async function understand(env, list, transcript) {
  const candidates = env.MODEL ? [env.MODEL] : [...PREFERRED_MODELS];
  const problems = [];
  for (let i = 0; i < candidates.length; i++) {
    const model = candidates[i];
    const r = await callModel(env.GEMINI_API_KEY, model, list, transcript);
    if (r.findings) return { model, findings: r.findings };
    problems.push(`${model}: ${r.problem}`);
    if (r.status === 429) return { status: 429, error: `free quota used up for now (${model})` };
    // Last resort: ask Google which models this key can use and take a Flash one.
    if (r.status === 404 && i === candidates.length - 1 && !env.MODEL) {
      const found = await availableFlash(env.GEMINI_API_KEY, candidates);
      if (found) candidates.push(found);
    }
  }
  return { status: 502, error: problems.join(' | ').slice(0, 500) };
}

/// One model, trying the ways of turning thinking off until one is accepted.
async function callModel(key, model, list, transcript) {
  for (const thinking of THINKING_OPTIONS) {
    const body = JSON.stringify({
      systemInstruction: { parts: [{ text: INSTRUCTIONS }] },
      contents: [{ role: 'user', parts: [{ text: `CONCEPTS:\n${list.join('\n')}\n\nTRANSCRIPT:\n${transcript}` }] }],
      generationConfig: {
        temperature: 0,
        responseMimeType: 'application/json',
        ...(thinking ? { thinkingConfig: thinking } : {}),
      },
    });
    let response;
    try {
      response = await fetch(`${API}/models/${model}:generateContent`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
        body,
        signal: AbortSignal.timeout(CALL_TIMEOUT_MS),
      });
    } catch (e) {
      return { status: 504, problem: e?.name === 'TimeoutError' ? `no answer in ${CALL_TIMEOUT_MS / 1000} s` : String(e) };
    }
    // 400 usually means this model doesn't accept that thinking setting.
    if (response.status === 400 && thinking) continue;
    if (!response.ok) {
      const detail = (await response.text()).slice(0, 200);
      return { status: response.status, problem: `error ${response.status}: ${detail}` };
    }
    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') ?? '';
    try {
      const parsed = JSON.parse(text);
      return { findings: Array.isArray(parsed.findings) ? parsed.findings : [] };
    } catch {
      return { status: 502, problem: 'did not return JSON' };
    }
  }
  return { status: 400, problem: 'rejected every request format' };
}

/// GET: which version is deployed and, with ?check, a tiny live test.
async function check(env, url) {
  const info = { service: 'SymptomBridge API', version: VERSION, key: Boolean(env.GEMINI_API_KEY) };
  if (!url.searchParams.has('check') || !env.GEMINI_API_KEY) return info;
  const started = Date.now();
  const result = await understand(env, ['chest_pain: dor no peito', 'fever: febre'], 'Doente: Tenho uma dor no peito.');
  return { ...info, seconds: (Date.now() - started) / 1000, ...result };
}

async function availableFlash(key, tried) {
  const r = await fetch(`${API}/models?pageSize=200`, { headers: { 'x-goog-api-key': key } });
  if (!r.ok) return null;
  const { models = [] } = await r.json();
  const usable = models
    .filter((m) => (m.supportedGenerationMethods || []).includes('generateContent'))
    .map((m) => m.name.replace(/^models\//, ''))
    .filter((name) => name.includes('flash') && !name.includes('image') && !name.includes('tts') && !tried.includes(name));
  // Newest first: names carry the version (gemini-3-flash before gemini-2.5-flash).
  usable.sort().reverse();
  return usable.find((n) => !n.includes('preview') && !n.includes('exp')) || usable[0] || null;
}
