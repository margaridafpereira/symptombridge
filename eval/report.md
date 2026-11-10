```
Development set, rules: 20 fictional cases
  Findings recalled          100 %  (74/74)
  Findings not in the case   0 %  (0/74)
  Negations understood       100 %  (12/12)
  Red flags caught           100 %  (8/8)
  False red flags            0
  Right condition first      100 %  (20/20)
  Right condition in top 3   100 %  (20/20)
```

```
Challenge set, rules: 10 fictional cases
  Findings recalled          44 %  (11/25)
  Findings not in the case   15 %  (2/13)
  Negations understood       0 %  (0/1)
  Red flags caught           0 %  (0/4)
  False red flags            1
  Right condition first      43 %  (3/7)
  Right condition in top 3   43 %  (3/7)
  Misses:
    h01 Family history is not the patient's history: missed [pleuritic] not in the case [cardiac_history] (a trap) red flags {acs}, expected {}
    h02 Colloquial Portuguese: missed [abdominal_pain, diarrhea, vomiting] top 3 [], expected gastroenteritis
    h03 Fever in the past, not now: negation missed [fever] not in the case [fever]
    h04 Answers that are not yes or no: missed [dyspnea, chest_pain] red flags {}, expected {acs} top 3 [], expected acs
    h05 Words outside the lexicon: missed [headache, photophobia] top 3 [], expected migraine
    h06 Stroke told by a relative, in their words: missed [face_droop, limb_weakness] red flags {}, expected {stroke} top 3 [], expected stroke
    h07 Indirect suicidal thoughts: missed [suicidal] red flags {}, expected {suicide}
    h09 Kidney pain and burning: missed [dysuria]
    h10 Speech recognition error: missed [sweating, nausea] red flags {}, expected {acs}
```

