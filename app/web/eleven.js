// ElevenLabs in the browser: playing questions, recording a consultation for
// Scribe, and the voice intake agent. The API key never comes here: every
// call goes through the SymptomBridge Worker, which holds it.
(function () {
  // Pinned SDK version; loaded only when the voice agent is started.
  const SDK_URLS = [
    'https://cdn.jsdelivr.net/npm/@elevenlabs/client@0.12.2/+esm',
    'https://cdn.jsdelivr.net/npm/@elevenlabs/client/+esm',
  ];

  let audio = null;
  let recorder = null;
  let chunks = [];
  let conversation = null;

  async function loadSdk() {
    let last;
    for (const url of SDK_URLS) {
      try {
        return await import(url);
      } catch (e) {
        last = e;
      }
    }
    throw new Error('could not load the ElevenLabs SDK: ' + (last && last.message));
  }

  window.sbVoice = {
    /// Plays an audio URL; resolves when it ends (or fails).
    play(url) {
      this.stopAudio();
      return new Promise((resolve, reject) => {
        audio = new Audio(url);
        audio.onended = () => resolve();
        audio.onerror = () => reject(new Error('could not play the audio'));
        audio.play().catch(reject);
      });
    },

    stopAudio() {
      if (audio) {
        audio.pause();
        audio = null;
      }
    },

    async recordStart() {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunks = [];
      recorder = new MediaRecorder(stream);
      recorder.ondataavailable = (e) => e.data.size && chunks.push(e.data);
      recorder.start(1000);
    },

    get recording() {
      return recorder !== null;
    },

    /// Stops recording and sends the audio to the Worker. Resolves with the
    /// Worker's JSON as a string: {"turns":[{"speaker":"clinician","text":"…"}]}.
    async recordStopAndTranscribe(endpoint) {
      if (!recorder) throw new Error('not recording');
      const r = recorder;
      recorder = null;
      const stopped = new Promise((resolve) => (r.onstop = resolve));
      r.stop();
      await stopped;
      r.stream.getTracks().forEach((t) => t.stop());
      const blob = new Blob(chunks, { type: r.mimeType || 'audio/webm' });
      chunks = [];
      const response = await fetch(endpoint, { method: 'POST', headers: { 'Content-Type': blob.type }, body: blob });
      const text = await response.text();
      if (!response.ok) throw new Error(text.slice(0, 300));
      return text;
    },

    recordCancel() {
      if (!recorder) return;
      recorder.stream.getTracks().forEach((t) => t.stop());
      recorder.stop();
      recorder = null;
      chunks = [];
    },

    /// Starts the voice agent. onLine(source, text) gets every spoken line
    /// ("user" or "ai"); onTool(name, paramsJson) must return a Promise of a
    /// string; onEnd(errorOrNull) fires once when the conversation is over.
    async agentStart(urlEndpoint, language, firstMessage, onLine, onTool, onEnd) {
      if (conversation) throw new Error('already talking');
      const response = await fetch(urlEndpoint);
      const body = await response.json().catch(() => ({}));
      if (!response.ok || !body.signed_url) throw new Error(body.error || 'could not start the voice agent');
      const { Conversation } = await loadSdk();
      await navigator.mediaDevices.getUserMedia({ audio: true });
      let ended = false;
      const finish = (error) => {
        if (ended) return;
        ended = true;
        conversation = null;
        onEnd(error || null);
      };
      conversation = await Conversation.startSession({
        signedUrl: body.signed_url,
        overrides: { agent: { language, firstMessage } },
        clientTools: {
          next_step: async (params) => onTool('next_step', JSON.stringify(params || {})),
        },
        onMessage: (m) => {
          const source = m.source || m.role;
          if (m.message) onLine(source === 'user' ? 'user' : 'ai', m.message);
        },
        onError: (message) => finish(typeof message === 'string' ? message : String(message && message.message || message)),
        onDisconnect: () => finish(null),
      });
    },

    async agentStop() {
      const c = conversation;
      conversation = null;
      if (c) await c.endSession();
    },
  };
})();
