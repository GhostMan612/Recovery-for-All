# Coach intent model assets

## Files

| File | Role |
|------|------|
| `coach_intent_vocab.txt` | token → id (shipped) |
| `coach_intent.tflite` | full-integer quantized classifier (generate locally) |

## Generate the INT8 model

From repo root (needs TensorFlow):

```bash
pip install tensorflow
python tools/train_coach_intent.py
```

Writes `coach_intent.tflite` (~tens of KB–low hundreds of KB) and refreshes the vocab.

## Runtime behavior

- `CoachTfliteIntentService` loads model only when RAM gate allows and assets exist.
- Crisis keywords always short-circuit **before** inference.
- Missing / failed model → pure keyword `RecoveryCoachService` (already shipped).
- Chatbot shell uses scripted coach offline-first; Ollama remains optional deeper path.
