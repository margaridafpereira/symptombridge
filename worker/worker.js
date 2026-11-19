// SymptomBridge API: a Cloudflare Worker that keeps the Gemini and
// ElevenLabs keys secret.
//
// POST /            Gemini: which clinical concepts a transcript mentions,
//                   by whom, and with which exact words.
// GET  /tts         ElevenLabs: one of the app's own questions read aloud.
//                   Only sentences in the SPOKEN list below; each one is
//                   cached, so it is generated once.
// POST /transcribe  ElevenLabs Scribe: a recorded consultation, returned as
//                   clinician and patient turns.
// GET  /agent       ElevenLabs Agents: a short-lived link to talk to the
//                   voice intake agent.
// The prompts and the allowlist live here, not in the browser, so the
// Worker cannot be used as a free general-purpose proxy.
//
// Setup (Cloudflare dashboard → the Worker → Settings → Variables and Secrets):
//   Secret GEMINI_API_KEY, Secret ELEVENLABS_API_KEY
//   Text ELEVENLABS_AGENT_ID (the voice agent), optional Text
//   ELEVENLABS_VOICE_PT / ELEVENLABS_VOICE_EN (voice ids), MODEL (forces one
//   Gemini model), ALLOWED_ORIGINS (comma separated)
// Nothing is stored or logged; only the generated question audio is cached.
//
// Open the Worker's address with ?check in a browser to see which version is
// deployed, which model answers and how long it takes.

const VERSION = '2026-11-19-voice2';

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

const ELEVEN = 'https://api.elevenlabs.io/v1';
const DEFAULT_VOICE = 'EXAVITQu4vr4xnSDxMaL'; // a stock multilingual voice
// Multilingual v2 keeps the accent of the chosen voice (Flash with a
// language code drifts to Brazilian Portuguese). Each question is cached,
// so the higher cost is paid once.
const TTS_MODEL = 'eleven_multilingual_v2';
const MAX_AUDIO_BYTES = 20 * 1024 * 1024; // about 20 minutes of compressed speech

const INSTRUCTIONS = `You read transcripts of medical consultations in European Portuguese or English.
Some lines start with "Médico:" or "Doctor:" (clinician), or "Doente:" or "Patient:" (patient);
lines without a label are the patient. Quote in the language of the transcript.

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
("soares frios" = "suores frios"). In English, the same: colloquial words ("the runs" =
diarrhoea, "throwing up" = vomiting), indirect statements ("everyone would be better off
without me" = thoughts of suicide) and speech-recognition errors.
Do not diagnose. Return only concepts actually supported by the transcript.

Answer only with JSON: {"findings": [ ... ]}`;

export default {
  async fetch(request, env, ctx) {
    const origins = (env.ALLOWED_ORIGINS || DEFAULT_ORIGINS).split(',').map((s) => s.trim());
    const origin = request.headers.get('Origin') || '';
    const cors = {
      'Access-Control-Allow-Origin': origins.includes(origin) ? origin : origins[0],
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
      'Vary': 'Origin',
    };
    const reply = (status, body) =>
      new Response(JSON.stringify(body, null, 2), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

    if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '');
    // An <audio> element sends no Origin; /tts is protected by its allowlist.
    if (path.endsWith('/tts') && request.method === 'GET') return speak(request, env, ctx, url, cors);
    // Browsers always send Origin; the evaluation script sends none.
    if (origin && !origins.includes(origin)) return reply(403, { error: 'origin not allowed' });
    if (path.endsWith('/agent') && request.method === 'GET') return agentLink(env, reply);
    if (path.endsWith('/transcribe') && request.method === 'POST') return transcribe(request, env, url, reply);
    if (request.method === 'GET') return reply(200, await check(env, url));
    if (request.method !== 'POST') return reply(405, { error: 'POST only' });
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
  const info = {
    service: 'SymptomBridge API',
    version: VERSION,
    key: Boolean(env.GEMINI_API_KEY),
    elevenlabs: Boolean(env.ELEVENLABS_API_KEY),
    agent: Boolean(env.ELEVENLABS_AGENT_ID),
  };
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

// ---------------------------------------------------------------- ElevenLabs

/// GET /tts?lang=pt&text=…: one of the app's own sentences as speech.
async function speak(request, env, ctx, url, cors) {
  const lang = url.searchParams.get('lang') === 'en' ? 'en' : 'pt';
  const text = (url.searchParams.get('text') || '').trim();
  const fail = (status, error) =>
    new Response(JSON.stringify({ error }), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
  if (!(SPOKEN[lang] || []).includes(text)) return fail(403, 'only the app\'s own questions can be read aloud');
  if (!env.ELEVENLABS_API_KEY) return fail(500, 'ELEVENLABS_API_KEY is not set');

  const cache = caches.default;
  const key = new Request(`${url.origin}/tts?lang=${lang}&text=${encodeURIComponent(text)}&m=${TTS_MODEL}&v=${env.ELEVENLABS_VOICE_PT || ''}${env.ELEVENLABS_VOICE_EN || ''}`);
  const hit = await cache.match(key);
  if (hit) return hit;

  const voice = (lang === 'en' ? env.ELEVENLABS_VOICE_EN : env.ELEVENLABS_VOICE_PT) || DEFAULT_VOICE;
  const r = await fetch(`${ELEVEN}/text-to-speech/${voice}?output_format=mp3_44100_64`, {
    method: 'POST',
    headers: { 'xi-api-key': env.ELEVENLABS_API_KEY, 'Content-Type': 'application/json', Accept: 'audio/mpeg' },
    body: JSON.stringify({ text, model_id: TTS_MODEL }),
  });
  if (!r.ok) return fail(r.status, `ElevenLabs ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const response = new Response(await r.arrayBuffer(), {
    headers: { ...cors, 'Content-Type': 'audio/mpeg', 'Cache-Control': 'public, max-age=31536000, immutable' },
  });
  ctx.waitUntil(cache.put(key, response.clone()));
  return response;
}

/// GET /agent: a signed, short-lived link to the voice intake agent.
async function agentLink(env, reply) {
  if (!env.ELEVENLABS_API_KEY) return reply(500, { error: 'ELEVENLABS_API_KEY is not set' });
  if (!env.ELEVENLABS_AGENT_ID) return reply(500, { error: 'ELEVENLABS_AGENT_ID is not set' });
  const r = await fetch(`${ELEVEN}/convai/conversation/get-signed-url?agent_id=${encodeURIComponent(env.ELEVENLABS_AGENT_ID)}`, {
    headers: { 'xi-api-key': env.ELEVENLABS_API_KEY },
  });
  const body = await r.json().catch(() => ({}));
  if (!r.ok || !body.signed_url) return reply(r.status || 502, { error: `ElevenLabs ${r.status}: ${JSON.stringify(body).slice(0, 200)}` });
  return reply(200, { signed_url: body.signed_url });
}

/// POST /transcribe?lang=pt with the recorded audio as the body. Scribe
/// separates the voices; the one asking more questions is the clinician.
async function transcribe(request, env, url, reply) {
  if (!env.ELEVENLABS_API_KEY) return reply(500, { error: 'ELEVENLABS_API_KEY is not set' });
  const audio = await request.arrayBuffer();
  if (audio.byteLength === 0) return reply(400, { error: 'no audio' });
  if (audio.byteLength > MAX_AUDIO_BYTES) return reply(413, { error: 'recording too long' });
  const type = request.headers.get('Content-Type') || 'audio/webm';

  const form = new FormData();
  form.append('file', new File([audio], 'consultation.webm', { type }));
  form.append('model_id', 'scribe_v1');
  form.append('language_code', url.searchParams.get('lang') === 'en' ? 'eng' : 'por');
  form.append('diarize', 'true');
  form.append('num_speakers', '2');
  form.append('tag_audio_events', 'false');
  const r = await fetch(`${ELEVEN}/speech-to-text`, {
    method: 'POST',
    headers: { 'xi-api-key': env.ELEVENLABS_API_KEY },
    body: form,
  });
  if (!r.ok) return reply(r.status, { error: `ElevenLabs ${r.status}: ${(await r.text()).slice(0, 200)}` });
  const data = await r.json();
  return reply(200, { turns: toTurns(data) });
}

/// Scribe's words, each with a speaker id, grouped into turns.
function toTurns(data) {
  const segments = [];
  for (const w of data.words || []) {
    if (w.type === 'audio_event') continue;
    const speaker = w.speaker_id || 'speaker_0';
    const last = segments[segments.length - 1];
    if (last && last.id === speaker) last.text += w.text;
    else if (w.type !== 'spacing') segments.push({ id: speaker, text: w.text });
  }
  if (segments.length === 0 && data.text) segments.push({ id: 'speaker_0', text: data.text });
  const questions = {};
  for (const s of segments) questions[s.id] = (questions[s.id] || 0) + (s.text.match(/\?/g) || []).length;
  const ids = [...new Set(segments.map((s) => s.id))];
  // Most questions wins; on a tie, whoever spoke first (clinicians usually open).
  const clinician = ids.length < 2 ? null : ids.reduce((a, b) => ((questions[b] || 0) > (questions[a] || 0) ? b : a));
  return segments.map((s) => ({ speaker: s.id === clinician ? 'clinician' : 'patient', text: s.text.trim() }));
}

// SPOKEN-BEGIN: generated from the app by `flutter test` (UPDATE_SPOKEN=1); do not edit by hand.
const SPOKEN = {
  "pt": [
    "A dor vai para o braço, maxilar ou pescoço?",
    "A dor é debaixo das costelas, do lado direito?",
    "A dor é em baixo, do lado direito?",
    "A dor é nas costas, de um lado?",
    "A luz incomoda-o?",
    "Alivia quando se inclina para a frente?",
    "Aparece com o esforço, como subir escadas?",
    "Arde quando urina?",
    "As fezes estão pretas?",
    "Chegou a desmaiar?",
    "Começou de repente, em segundos?",
    "Começou depois de uma refeição gordurosa?",
    "Começou à volta do umbigo e depois mudou de sítio?",
    "De 0 a 10, quanto lhe dói?",
    "Dói quando carrega no sítio?",
    "Dói-lhe a garganta?",
    "Fez alguma viagem longa, cirurgia ou esteve acamado?",
    "Fuma, ou tem diabetes, tensão alta ou colesterol?",
    "Há quanto tempo começou?",
    "Já lhe disseram que tem insuficiência cardíaca?",
    "Já tossiu sangue?",
    "Notou a cara ou a boca descaída?",
    "Obrigado. O médico vai ver as suas respostas antes de o chamar.",
    "Olá. O que o traz cá hoje? Conte-me com as suas palavras.",
    "Ouve um chiar a respirar?",
    "Piora quando respira fundo?",
    "Pode estar grávida?",
    "Por favor, avise já um profissional de saúde. Se estiver em casa, ligue 112.",
    "Sente o coração acelerado?",
    "Tem DPOC?",
    "Tem alguma doença do coração?",
    "Tem arrepios?",
    "Tem as pernas inchadas?",
    "Tem asma?",
    "Tem azia ou sabor ácido na boca?",
    "Tem diarreia?",
    "Tem dificuldade em falar?",
    "Tem dor de barriga?",
    "Tem dor de cabeça?",
    "Tem dor no peito?",
    "Tem dores no corpo?",
    "Tem estado confuso ou sonolento?",
    "Tem expetoração?",
    "Tem falta de ar mesmo parado?",
    "Tem falta de ar quando se deita?",
    "Tem falta de ar?",
    "Tem falta de força num braço ou perna?",
    "Tem febre?",
    "Tem manchas na pele?",
    "Tem náuseas?",
    "Tem o nariz entupido ou a pingar?",
    "Tem o pescoço rígido?",
    "Tem os lábios, a língua ou a garganta inchados?",
    "Tem suores?",
    "Tem tonturas?",
    "Tem tosse?",
    "Tem urinado muitas vezes?",
    "Tem vomitado?",
    "Viu sangue na urina?",
    "Vomitou sangue?",
    "É a pior dor de cabeça da sua vida?"
  ],
  "en": [
    "Aching all over?",
    "Any black stools?",
    "Any blood in the vomit?",
    "Any blood in your urine?",
    "Any blood when you cough?",
    "Any chest pain?",
    "Any chills?",
    "Any confusion or drowsiness?",
    "Any cough?",
    "Any diarrhoea?",
    "Any dizziness?",
    "Any drooping of the face?",
    "Any fever?",
    "Any headache?",
    "Any heart disease before?",
    "Any heartburn or acid taste?",
    "Any nausea?",
    "Any palpitations?",
    "Any rash?",
    "Any recent long trip, surgery or bed rest?",
    "Any shortness of breath?",
    "Any sore throat?",
    "Any sweating?",
    "Any swelling in the legs?",
    "Any swelling of lips, tongue or throat?",
    "Any trouble speaking?",
    "Any tummy pain?",
    "Any vomiting?",
    "Any weakness in an arm or leg?",
    "Any wheezing?",
    "Are you breathless lying flat?",
    "Are you coughing up phlegm?",
    "Are you passing urine more often?",
    "Are you short of breath even at rest?",
    "Could you be pregnant?",
    "Did it start after a fatty meal?",
    "Did it start around the navel and then move?",
    "Did it start suddenly, within seconds?",
    "Did you faint?",
    "Do you have COPD?",
    "Do you have asthma?",
    "Do you smoke, or have diabetes, high blood pressure or cholesterol?",
    "Does it burn when you pass urine?",
    "Does it come on with effort, like stairs?",
    "Does it hurt when you press on it?",
    "Does light bother you?",
    "Does the pain spread to the arm, jaw or neck?",
    "From 0 to 10, how bad is the pain?",
    "Have you been told your heart is weak?",
    "Hello. What brings you in today? Tell me in your own words.",
    "How long ago did it start?",
    "Is it better leaning forward?",
    "Is it the worst headache of your life?",
    "Is it worse when you breathe in deeply?",
    "Is the pain in the side of the back?",
    "Is the pain low on the right side?",
    "Is the pain under the right ribs?",
    "Is your neck stiff?",
    "Please tell a healthcare professional now. If you are at home, call 112.",
    "Runny or blocked nose?",
    "Thank you. The doctor will read your answers before calling you in."
  ]
};
// SPOKEN-END
