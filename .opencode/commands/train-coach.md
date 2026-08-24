---
description: Retrain the coach intent classifier (TF 3.12 venv)
---
Retrain the TFLite coach intent model. Steps:

1. If `.venv-tf/` is missing, create it:
   `python -m uv venv .venv-tf --python 3.12` then
   `python -m uv pip install --python .venv-tf numpy tensorflow-cpu`
2. Run `.venv-tf\Scripts\python.exe tools/train_coach_intent.py`
   (system Python is 3.14 — TensorFlow has no wheels for it; ALWAYS use
   the venv).
3. Confirm `assets/models/coach_intent.tflite` + `coach_intent_vocab.txt`
   were rewritten, and report the new model size in bytes.
4. Remind the user both artifacts are committed and need staging.

$ARGUMENTS — optional extra instruction (e.g., "expand the urge phrases").
