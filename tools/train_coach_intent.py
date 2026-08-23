#!/usr/bin/env python3
"""
Recovery-for-All — tiny coach intent classifier
Train a small embedding + dense model, export full-integer INT8 TFLite.

Usage (Python 3.10-3.12 with TensorFlow; a 3.12 venv is reproducible via uv):
  python -m uv venv .venv-tf --python 3.12
  python -m uv pip install --python .venv-tf numpy tensorflow-cpu
  .venv-tf/Scripts/python tools/train_coach_intent.py      # Windows
  # writes:
  #   assets/models/coach_intent.tflite        (~14 KB, committed)
  #   assets/models/coach_intent_vocab.txt     (committed)

Target: low-RAM Android (1-2 GB usable). Full integer quantization.
Crisis labels are included for calibration only; runtime still short-circuits
crisis via keyword before the model runs.
"""

from __future__ import annotations

import os
import random
from pathlib import Path

import numpy as np
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "models"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Must match CoachTfliteIntentService.labelOrder
LABELS = [
    "crisis",
    "urge",
    "checkIn",
    "walk",
    "gratitude",
    "appHelpPet",
    "appHelpSos",
    "appHelpDresser",
    "greeting",
    "unknown",
]
LABEL_TO_ID = {n: i for i, n in enumerate(LABELS)}

# Synthetic recovery-safe phrases (expand offline as needed)
PHRASES: dict[str, list[str]] = {
    "crisis": [
        "i want to die",
        "kill myself",
        "thinking about suicide",
        "end my life",
        "hurt myself",
        "no reason to live",
        "wanna die tonight",
    ],
    "urge": [
        "i have an urge",
        "strong craving right now",
        "feeling triggered",
        "tempted to use",
        "relapse thoughts",
        "craving is high",
        "slip is close",
    ],
    "checkIn": [
        "mood check in",
        "how am i feeling",
        "check-in please",
        "feeling today",
        "quick mood check",
    ],
    "walk": [
        "i went for a walk",
        "log my steps",
        "did some movement",
        "walked outside",
        "exercise today",
    ],
    "gratitude": [
        "i am grateful",
        "thankful for today",
        "one blessing",
        "appreciate my friend",
        "gratitude practice",
    ],
    "appHelpPet": [
        "how does the pet work",
        "companion sparks",
        "what is bond energy",
        "path companion help",
        "avatar outfit energy",
    ],
    "appHelpSos": [
        "sos notification",
        "how to call 988",
        "sponsor number settings",
        "crisis line in app",
        "emergency help numbers",
    ],
    "appHelpDresser": [
        "open the dresser",
        "customize avatar",
        "unlock cosmetics",
        "seasonal outfit",
        "change clothes on pet",
    ],
    "greeting": [
        "hello",
        "hi there",
        "hey coach",
        "good morning",
        "good evening",
    ],
    "unknown": [
        "what is the weather",
        "random noise xyz",
        "tell me a joke",
        "stock prices",
        "unrelated question",
    ],
}

MAX_LEN = 64
VOCAB_SIZE_CAP = 2000
EMBED_DIM = 32
EPOCHS = 48
BATCH = 16


def build_corpus() -> list[tuple[str, int]]:
    rng = random.Random(42)
    rows: list[tuple[str, int]] = []
    for name, phrases in PHRASES.items():
        lid = LABEL_TO_ID[name]
        for p in phrases:
            base = p.lower()
            rows.append((base, lid))
            # light augmentation
            rows.append((base + " please", lid))
            rows.append(("please " + base, lid))
            # word-dropout augmentation (never drop the first word)
            words = base.split()
            if len(words) > 2:
                dropped = [words[0]] + [
                    w for w in words[1:] if rng.random() > 0.35
                ]
                if len(dropped) >= 2 and " ".join(dropped) != base:
                    rows.append((" ".join(dropped), lid))
    rng.shuffle(rows)
    return rows


def build_vocab(texts: list[str]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for t in texts:
        for tok in t.replace("'", " ").split():
            tok = "".join(c for c in tok if c.isalnum())
            if not tok:
                continue
            counts[tok] = counts.get(tok, 0) + 1
    # specials
    vocab = {"<PAD>": 0, "<UNKNOWN>": 1, "<START>": 2}
    for tok, _ in sorted(counts.items(), key=lambda x: (-x[1], x[0])):
        if tok in vocab:
            continue
        if len(vocab) >= VOCAB_SIZE_CAP:
            break
        vocab[tok] = len(vocab)
    return vocab


def encode(text: str, vocab: dict[str, int]) -> list[int]:
    toks = []
    for raw in text.lower().replace("'", " ").split():
        tok = "".join(c for c in raw if c.isalnum())
        if tok:
            toks.append(tok)
    ids = [vocab["<START>"]]
    unk = vocab["<UNKNOWN>"]
    for t in toks:
        ids.append(vocab.get(t, unk))
        if len(ids) >= MAX_LEN:
            break
    while len(ids) < MAX_LEN:
        ids.append(vocab["<PAD>"])
    return ids[:MAX_LEN]


def main() -> None:
    random.seed(42)
    np.random.seed(42)
    tf.random.set_seed(42)

    rows = build_corpus()
    texts = [r[0] for r in rows]
    labels = np.array([r[1] for r in rows], dtype=np.int32)
    vocab = build_vocab(texts)

    x = np.array([encode(t, vocab) for t in texts], dtype=np.int32)
    y = tf.keras.utils.to_categorical(labels, num_classes=len(LABELS))

    # tiny model — float token IDs in (cast to int inside), softmax out.
    # Explicit masked-mean pooling (conversion-safe): pad tokens must NOT
    # dilute short phrases, otherwise every input pools to the same vector.
    inp = tf.keras.Input(shape=(MAX_LEN,), dtype=tf.float32)
    tokens = tf.keras.layers.Lambda(lambda t: tf.cast(t, tf.int32))(inp)
    emb = tf.keras.layers.Embedding(len(vocab), EMBED_DIM, mask_zero=False)(tokens)
    mask = tf.keras.layers.Lambda(
        lambda t: tf.cast(tf.not_equal(t, 0), tf.float32)
    )(inp)
    mask3 = tf.keras.layers.Lambda(lambda m: tf.expand_dims(m, -1))(mask)
    emb_masked = tf.keras.layers.Multiply()([emb, mask3])
    summed = tf.keras.layers.Lambda(lambda e: tf.reduce_sum(e, axis=1))(emb_masked)
    denom = tf.keras.layers.Lambda(
        lambda m: tf.maximum(tf.reduce_sum(m, axis=1, keepdims=True), 1.0)
    )(mask)
    pooled = tf.keras.layers.Lambda(lambda a: a[0] / a[1])([summed, denom])
    h = tf.keras.layers.Dense(64, activation="relu")(pooled)
    h = tf.keras.layers.Dropout(0.2)(h)
    out = tf.keras.layers.Dense(len(LABELS), activation="softmax")(h)
    model = tf.keras.Model(inp, out)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy"],
    )
    model.fit(x, y, epochs=EPOCHS, batch_size=BATCH, verbose=1, validation_split=0.15)

    # save vocab
    vocab_path = OUT_DIR / "coach_intent_vocab.txt"
    with vocab_path.open("w", encoding="utf-8") as f:
        for tok, idx in sorted(vocab.items(), key=lambda kv: kv[1]):
            f.write(f"{tok} {idx}\n")
    print("wrote", vocab_path)

    # full integer quantization (weights/activations INT8, float I/O)
    def representative():
        for i in range(min(100, len(x))):
            yield [x[i : i + 1].astype(np.float32)]

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = representative
    converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
    converter.inference_input_type = tf.float32
    converter.inference_output_type = tf.float32
    tflite_model = converter.convert()

    model_path = OUT_DIR / "coach_intent.tflite"
    model_path.write_bytes(tflite_model)
    print("wrote", model_path, "bytes=", len(tflite_model))


if __name__ == "__main__":
    main()
