# WO-GGUF-01 — Non-destructive local model download and storage budgeting

**Priority:** P1 data preservation and device storage  
**State:** DESIGN ONLY; no production-code changes in this PR  
**Evidence:** `lib/services/gguf_model_service.dart::_ensureBudget`, `downloadModel`, `isModelReady`, `test/gguf_services_test.dart`, and Settings' GGUF model-management actions.

## Verified failure mode

The model budget is 3 GiB, and `_ensureBudget` currently frees space by **deleting other downloaded `.gguf` files, largest first, *before* the replacement model download starts**. Network timeout, cancellation, corrupt digest, DNS failure, ENOSPC or a user leaving the download can therefore leave the device with neither the newly requested model nor its previously installed working model. The tests currently assert that eviction succeeds but do not cover preservation when the subsequent download fails. A separate integrity PR (#13, merged) checks pinned SHA-256 of existing model files before inference; this protects trust, not availability.

## Proposed policy and explicit decision

**Preferred decision:** Never automatically delete an unrelated installed model as a side effect of tapping Download. If the new download plus existing files and a write margin exceed the budget, return a precise `insufficientBudget` state listing estimated bytes and safe deletion choices. Ask the user to **explicitly** delete selected installed models in a separate action, with an honest warning that deletion cannot be rolled back without re-downloading. No hidden automatic eviction.

Alternative 'pre-authorized eviction' strategies still have irrecoverable failure windows and should not be described as atomic or lossless.

## Implementation workchain

1. **Pure preflight:** Replace delete-as-you-check behavior with a read-only budget calculation: existing `.gguf`, in-flight `.tmp`, target sizes, projected temp margin and current cache lease/active inference. Avoid reading every model hash during an arithmetic preflight. Do not trust SharedPreferences as the filesystem ledger.
2. **Bounded concurrency:** Serialize or reserve model transfers, so two concurrent downloads cannot each pass independent budget checks. Cancellation and exceptions must close `http.Client` and remove their own temporary files without touching already installed models.
3. **Explicit delete:** Present actual model name, bytes freed, active-use impact and reacquisition requirement. Refuse deletion of a model in use or coordinate unload first; delete only an allowlisted catalog ID. Preserve prefs on failed file deletion.
4. **Verified commit:** Stream to a unique `.tmp` in app-private storage. Validate size/content and the catalog-pinned SHA-256 before final rename. Do not replace a valid original model until the new complete file has passed validation and is ready for atomic promotion. Crash restart should clean orphan `.tmp` without erasing valid models.
5. **UX states:** Distinguish `alreadyVerified`, `needsSpace`, `awaitingUserDelete`, `downloading`, `cancelled`, `networkFailed`, `outOfSpace`, `hashFailed` and `installed`. Report cumulative storage consumption honestly: the app's self-imposed 3 GiB budget is **not** a physical free-space API.
6. **Efficiency:** The current pinned SHA-256 cache validation reads full models on each `getModelPath`; measure on representative lower-RAM devices. Any optimization must preserve an integrity check before unsafe native inference rather than reverting to 'exists + 1MB'.

## Required tests

- A budget failure preserves the exact old file bytes **and** registry, even after repeated attempts.
- Network timeout, cancellation, 404, malformed content, bad SHA-256, interrupted stream, simulated disk full and rename failure never delete a verified old model.
- Two overlapping downloads obey the same aggregate budget without overcommitting; restart prunes only orphan temporary files.
- Test explicit user-selected deletion success and filesystem refusal; bad/unknown traversal IDs cannot affect unrelated app files.
- Holdback: the existing 'over-budget auto-evicts models' tests must be changed to assert the **opposite preservation invariant** after the new policy is implemented.

## End-of-plan acceptance

Run analyzer, full Flutter tests, invariant/selftests and Firestore emulator suite. On a representative low-storage Android phone, install a verified model, initiate a larger one, cancel mid-stream, restart and prove the original still loads and generates. Repeat after corrupted download and simulated storage exhaustion. Capture storage usage and worst-case model validation latency; no claim of zero-downtime install without device proof.

**Excluded:** No new model provider, no runtime network endpoint or cloud prompt, no signed AAB claim, and no destruction of user files outside the allowlisted model cache.
