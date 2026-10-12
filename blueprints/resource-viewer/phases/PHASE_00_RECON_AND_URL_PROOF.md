# Phase 00 — Reconnaissance and official URL proof

**State (2026-10-12):** PARTIALLY RECONCILED · **Live PDF response observed; full endpoint/content/device proof BLOCKED** · **Creates no feature code**

## Reconciled progress

- Current source and test paths were inspected; the Resource Viewer is not a scaffold-only package.
- Literature and Community Resources use the shared router; SOS, phone/dialer, map/directions, meeting-join, settings/legal, housing, onboarding, donation, and Wellbriety links have explicit dispositions in `07_LINK_INVENTORY.md`.
- The registry remains marked unverified. A live fetch in this task retrieved PDF-format responses for all twelve current aa.org candidates; the tool exposed `application/pdf`, `%PDF-1.7`, and each PDF's linearized length/page-count fields. It did not expose HTTP status, response headers, redirect chain/final URL, complete bytes or a content digest, and the encrypted PDF text was not inspected to confirm chapter identity. This is partial endpoint evidence, not release verification.
- The pre-change branch/dirty-state and installed toolchain/device baseline were not captured in this session record and cannot be reconstructed as contemporaneous evidence. Current host gates and physical-device/release behavior still require the final batch. Do not promote Phase 00 to complete.
- Inventory covers the observed source launchers and their current dispositions; it is not proof of an exhaustive runtime navigation graph.

## Tasks

1. **Partially complete:** repository laws and current source were reviewed; contemporaneous pre-change Git/device/toolchain facts are not available. Do not invent them.
2. **Partially complete:** observed launcher inventory and flow boundaries are recorded in `07_LINK_INVENTORY.md`; direct source search does not establish runtime exhaustiveness.
3. **Source-reviewed:** PDF ownership, workbook path, resource policy and pinned WebView package are inspected. Installed toolchain/device compatibility remains pending.
4. **Partially observed:** all twelve current candidates returned PDF-format content from the requested aa.org URLs on 2026-10-12; see the response observations below. HTTP status, redirect chain/final URL, complete-response digest, per-chapter text match, current viewing terms, and device rendering remain unverified. Keep the app registry unverified.
5. **Pending:** review current AA terms for transient personal viewing; do not assume redistribution permission.
6. **Partially complete:** SOS and native/system flows are dispositioned; WebView platform compatibility and unobserved popup/download paths remain pending.
7. **Not complete:** the live observations below are recorded, but they are not complete response records and have no independent sign-off.

## Live endpoint observations (2026-10-12)

The official [A.A. Twelve Steps page](https://www.aa.org/the-twelve-steps) was also fetched and presents the Steps in numeric order. Each URL below was separately fetched from its direct aa.org candidate. The fetch tool reported `application/pdf`; the body prefix was `%PDF-1.7`. `/L` and `/N` are values observed in each PDF's linearization dictionary, not independently measured transfer lengths or proof of chapter contents.

| Step | Requested candidate | PDF `/L` bytes | PDF `/N` pages | Fetch result |
|---:|---|---:|---:|---|
| 1 | `https://www.aa.org/sites/default/files/2022-01/en_step1.pdf` | 49,596 | 4 | PDF MIME and signature observed |
| 2 | `https://www.aa.org/sites/default/files/2022-01/en_step2.pdf` | 63,850 | 9 | PDF MIME and signature observed |
| 3 | `https://www.aa.org/sites/default/files/2022-01/en_step3.pdf` | 61,894 | 8 | PDF MIME and signature observed |
| 4 | `https://www.aa.org/sites/default/files/2022-01/en_step4.pdf` | 79,097 | 13 | PDF MIME and signature observed |
| 5 | `https://www.aa.org/sites/default/files/2022-01/en_step5.pdf` | 60,114 | 8 | PDF MIME and signature observed |
| 6 | `https://www.aa.org/sites/default/files/2022-01/en_step6.pdf` | 56,741 | 7 | PDF MIME and signature observed |
| 7 | `https://www.aa.org/sites/default/files/2022-01/en_step7.pdf` | 56,917 | 7 | PDF MIME and signature observed |
| 8 | `https://www.aa.org/sites/default/files/2022-01/en_step8.pdf` | 51,524 | 6 | PDF MIME and signature observed |
| 9 | `https://www.aa.org/sites/default/files/2022-01/en_step9.pdf` | 47,002 | 5 | PDF MIME and signature observed |
| 10 | `https://www.aa.org/sites/default/files/2022-01/en_step10.pdf` | 59,352 | 8 | PDF MIME and signature observed |
| 11 | `https://www.aa.org/sites/default/files/2022-01/en_step11.pdf` | 68,644 | 10 | PDF MIME and signature observed |
| 12 | `https://www.aa.org/sites/default/files/2022-01/en_step12.pdf` | 108,325 | 20 | PDF MIME and signature observed |

These observations establish that each requested URL yielded a PDF-formatted response at observation time; they do **not** prove HTTP status, absence of redirects, final response host, semantic Step N correspondence, stable availability, licensing, or Android WebView/native-reader compatibility. Do not flip `validated` in the candidate registry from this limited evidence alone.

## Gate criteria (evaluate with end-of-plan batch or targeted non-shell source review)

- Exact Step 1..12 candidates and partial live PDF-format observations are recorded above; full response and content verification remains blocked.
- Observed external launchers are dispositioned for this migration; runtime inventory completeness remains unknown.
- Native PDF component and ownership boundaries understood; no reason to duplicate PDF parser.
- Version-appropriate WebView dependency selected or explicitly blocked.
- No pre-existing dirty changes overwritten; no code edits until scope reconcile done.
