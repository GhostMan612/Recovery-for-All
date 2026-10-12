# AGENTS.md — Resource viewer test subsystem

**Status: host tests present; final gate run pending.** Existing tests cover the AA registry shape, URL trust and redirects, PDF validation/cancellation/private-cache cleanup, workbook ownership, router navigation, step-state preservation, and WebView controller behavior.

Continue using injectable collaborators and negative controls so tests prove a known bad case fails, not only that fixtures exist. Add regressions for any changed behavior. Host tests cannot prove real WebView/PDF native platform behavior: require Android release-device evidence. Follow root `AGENTS.md` rule: execute the full gate suite only in the final end-of-plan batch.
