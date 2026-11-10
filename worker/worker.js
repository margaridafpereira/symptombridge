// SymptomBridge API: a Cloudflare Worker that keeps the Gemini key secret.
//
// It does one job only: given a consultation transcript and the engine's
// list of clinical concepts, it asks Gemini which concepts were mentioned,
// by whom, and with which exact words. The prompt lives here, not in the
// browser, so the Worker cannot be used as a free general-purpose proxy.
//
// Setup (Cloudflare dashboard → the Worker):
//   Settings → Variables and Secrets → Secret GEMINI_API_KEY
//   optional Text MODEL (default below), ALLOWED_ORIGINS (comma separated)
// Nothing is stored or logged.

const DEFAULT_MODEL = 'gemini-2.5-flash';
const DEFAULT_ORIGINS = 'https://margaridafpereira.github.io,http://localhost:8765';
const MAX_TRANSCRIPT = 6000; // characters, about ten minutes of speech
const MAX_CONCEPTS = 150;

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
      new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
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
    const transcript = typeof input.transcript === 'string' ? input.transcript : '';
    const concepts = Array.isArray(input.concepts) ? input.concepts : [];
    if (!transcript.trim()) return reply(400, { error: 'transcript is empty' });
    if (transcript.length > MAX_TRANSCRIPT) return reply(413, { error: 'transcript too long' });
    if (concepts.length === 0 || concepts.length > MAX_CONCEPTS) return reply(400, { error: 'bad concept list' });
    const list = [];
    for (const c of concepts) {
      if (!c || !/^[a-z_]{2,40}$/.test(c.id) || typeof c.label !== 'string' || c.label.length > 100) {
        return reply(400, { error: 'bad concept' });
      }
      list.push(`${c.id}: ${c.label}`);
    }

    const model = env.MODEL || DEFAULT_MODEL;
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': env.GEMINI_API_KEY },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: INSTRUCTIONS }] },
        contents: [{ role: 'user', parts: [{ text: `CONCEPTS:\n${list.join('\n')}\n\nTRANSCRIPT:\n${transcript}` }] }],
        generationConfig: { temperature: 0, responseMimeType: 'application/json' },
      }),
    });
    if (response.status === 429) return reply(429, { error: 'free quota used up for now' });
    if (!response.ok) return reply(502, { error: `model error ${response.status}` });

    const data = await response.json();
    const text = data?.candidates?.[0]?.content?.parts?.map((p) => p.text).join('') ?? '';
    try {
      const parsed = JSON.parse(text);
      return reply(200, { model, findings: Array.isArray(parsed.findings) ? parsed.findings : [] });
    } catch {
      return reply(502, { error: 'model did not return JSON' });
    }
  },
};
