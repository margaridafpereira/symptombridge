# SymptomBridge

The patient describes their symptoms out loud, before the appointment (waiting room, at home) or during it. SymptomBridge transcribes, structures what was said and puts it on the clinician's screen: findings with the exact words they came from, red flags, and conditions to consider, each with what supports it, what argues against and what to ask next.

> Portfolio project. Not a medical device. It never gives the patient a diagnosis; everything goes to a clinician, who decides.

## Status: the engine, measured honestly

Right now this repo is the core engine (`engine/`, pure Dart): Portuguese speech in, findings / red flags / hypotheses out. Rules and an explicit knowledge base, no AI model yet, so it can't invent symptoms and every output points back to the patient's words.

It's checked against fictional cases (`eval/`):

| | Development set (20 cases) | Challenge set (10 cases) |
|---|---|---|
| Findings recalled | 100 % | **44 %** |
| Red flags caught | 8 / 8 | **0 / 4** |
| False red flags | 0 | 1 |
| Right condition in top 3 | 100 % | **43 %** |

The development set was written alongside the rules, so of course it scores 100 %. The challenge set was written afterwards to break it, and is never tuned against. It did:

- "ficou com a cara à banda e não consegue levantar o braço" (a stroke, in a relative's words) → no red flag;
- "às vezes penso que era melhor não estar cá" → no suicide-risk flag;
- "soares frios" (speech recognition mishearing "suores") → missed cardiac flag;
- "o meu pai morreu de enfarte" → counted as the patient's own heart disease (false alarm);
- "moinha", "tripa solta", "deitei tudo fora" → not understood.

That's the point of measuring: a hand-written lexicon handles the textbook phrasing and falls apart on how people actually talk. See [eval/report.md](eval/report.md) for every miss.

## Run it

```bash
cd engine
dart run example/demo.dart     # one transcript in, assessment out
dart test                      # both evaluation sets, report in eval/report.md
```

## Next

- A language-model layer for understanding (colloquial words, vague answers, who the symptom belongs to), with the fixed red-flag rules kept on top so a model can never switch a red flag off.
- The two apps: patient side (voice, guided questions) and the clinician's live screen.
