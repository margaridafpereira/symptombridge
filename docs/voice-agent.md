# The voice intake agent (ElevenLabs Agents)

The agent is configured in the ElevenLabs dashboard; the app only starts it through the Worker. This page is the configuration, so it can be rebuilt.

## 1. Create the agent

ElevenLabs dashboard → **Agents** → **Create agent** → blank agent, named `SymptomBridge intake`.

**First message:** `{{greeting}}`
(A dynamic variable: the app sends the opening question in the patient's language. Overrides would do the same but need a paid plan.)

**Default language:** Portuguese. Add **English** as an additional language.

**Voice:** any voice that sounds natural in European Portuguese and in English. The model must be a multilingual one (Flash v2.5 or Multilingual v2).

**System prompt:**

```
You are the reception assistant of a clinic. You interview a patient before their appointment so the doctor can read their answers first. You never diagnose, never name a disease and never give medical advice.

Speak only {{language_name}}. If it is Portuguese, use European Portuguese from Portugal, never Brazilian. Be warm and brief. One question at a time.

After EVERY answer from the patient, call the tool next_step with patient_answer set to the patient's own words, copied as they said them. Never decide the next question yourself; the tool decides it.

What the tool returns:
- urgent true: say tell_patient exactly, word for word, and nothing else about their condition. Then continue only if next_question is not empty.
- next_question: ask exactly that question. You may add a few words of empathy before it ("Compreendo.", "I see."), nothing more.
- finished true: say closing exactly, then end the conversation.

If the patient asks what they have, say the doctor will look at it shortly. If they go off topic, bring them back gently to the question.
```

## 2. The tool

Agent → **Tools** → **Add tool** → **Client tool** (it runs in the browser, where the rules engine is):

- **Name:** `next_step`
- **Description:** `Runs the clinic's safety rules on the patient's latest answer and returns what to say next. Call it after every patient answer.`
- **Wait for response:** on
- **Parameter:** `patient_answer`, type string, required, description `The patient's latest answer, in their own words.`

## 3. Security

Agent → **Security**:

- **Enable authentication:** on (the app gets a short-lived signed link from the Worker, so nobody can use the agent with your credits from elsewhere).
- **Overrides:** leave them off; the app uses dynamic variables instead.

Tools → **System tools**: turn on **End conversation** (the agent ends the call when the tool says the interview is finished) and **Detect language** (so it switches to English when the app is in English).

## 4. Connect it to the Worker

Copy the **agent ID** (on the agent page, `agent_…`). Cloudflare → the SymptomBridge Worker → **Settings → Variables and Secrets → Add** → type **Text**, name `ELEVENLABS_AGENT_ID`, value the agent ID → **Deploy**.

Open the Worker's address with `?check`: `"elevenlabs": true` and `"agent": true` mean it is ready.

## Why it is built this way

The agent talks; the rules decide. The questions, and above all the emergency message, come from the same tested rules engine as the rest of the app, so a red flag cannot be missed because a language model chose to say something else.
