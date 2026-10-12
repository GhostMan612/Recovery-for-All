# 08 — Release acceptance checklist

**Reconciled 2026-10-12.** Checklist marks are verification evidence, not source-presence markers. Current CI is green for the implementation commit and subsequent source-unchanged commit. A live fetch observed PDF MIME and `%PDF-1.7` responses for all twelve aa.org candidates; details and limitations are recorded in Phase 00. Full response/chapter identity checks, physical-device and release-artifact observations remain incomplete, so release acceptance is blocked.

| Scope | Source status | Verification status |
|---|---|---|
| Shared router/policy and primary Literature/Community links | Implemented in source | Host CI passed; device gate pending |
| Native PDF acquisition/reader and workbook reuse | Implemented in source | Host CI passed; device gate pending |
| Twelve Step per-chapter routing | Wired to explicit registry | 12/12 live fetches yielded PDF-format bodies; status/redirect/final-host and chapter-content match unverified; device proof pending |
| In-app WebView | Implemented in source | Host CI passed; Android device gates pending |
| Broader link callsites | Dispositioned in `07_LINK_INVENTORY.md` | Intentional external/native behavior not changed |
| Release acceptance | Not complete | No current-artifact signer/build/runtime proof in this task |

- [ ] Current branch/HEAD, dirty files, Dart/Flutter/AGP/Kotlin, device versions recorded before modification
- [x] Live fetch returned `application/pdf` and `%PDF-1.7` from all twelve requested aa.org candidate URLs on 2026-10-12; observed PDF `/L` and `/N` values are logged in Phase 00
- [ ] HTTP status, redirect chain/final host, complete transfer length/digest, and exact Step N content match independently verified for every endpoint
- [ ] Router classifies HTML, PDF, native OS intent and invalid/untrusted URL via centralized pure policy
- [ ] No uncontrolled `LaunchMode.externalApplication` for scoped built-in website/PDF links
- [ ] Twelve Steps N invokes PDF chapter N and **does not** open Chrome automatically
- [ ] Native PDF works using existing `flutter_pdfview`; imported workbook functionality unchanged
- [ ] Returning from native PDF returns to expanded step without losing user state
- [ ] PDF timeouts, size caps, cancellation, invalid content and cleanup proven on host and physical device
- [ ] Resource WebView supports current host, accessible close, back/forward, reload, load progress and visible failures
- [ ] Redirect policy, third-party link handling, schemes, JS, downloads and cookie policy tested
- [ ] SOS dialing, persistent notification and Recovery Circle not affected
- [ ] Offline behavior says offline (not a fake cached chapter) and does not strand user
- [ ] No persistent copyrighted chapter copies in Git, APK assets, cloud, public storage or repo
- [ ] No user recovery data or app-auth identity exposed to websites or logs
- [ ] Large text/theme/low-end UX validated against app standards
- [ ] End-of-plan analyze/test/colors/14 invariants/both selftests and relevant URL/resource gate all green
- [ ] Moto G 2025 and BLU View 5 smoke tests performed on **confirmed current** release artifact
- [ ] Release signer, native libs, versionCode/build provenance reviewed; Play release approved by human
- [ ] Documentation statuses match observed evidence; no phase is labeled verified or shipped solely because source is present
- [ ] Diff bounded to authorized work and pre-existing dirty files untouched

**Checklist interpretation:** the checked endpoint item records only a PDF-format response observation, not comprehensive verification. Unchecked items mean required evidence is not complete; they do not mean the source is only scaffolding. Host CI passed, while complete endpoint identity, device behavior and release acceptance remain unverified or blocked as listed above.
