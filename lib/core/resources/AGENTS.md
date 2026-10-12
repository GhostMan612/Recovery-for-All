# AGENTS.md — Resource routing and fetch subsystem

**Status: implementation present; final validation pending.** This directory contains `resource_request.dart`, `resource_policy.dart`, `resource_router.dart`, `pdf_acquirer.dart`, and `aa_step_resources.dart`. Read `blueprints/resource-viewer/README.md`, the relevant phase work orders, and repository root `AGENTS.md` and `RULES.md` before changing this subsystem.

Domain layer contract: URL/request parsing is pure and testable; allowlisting and redirect rules have one source of truth; PDFs are streamed into owned private temporary files, bounded and checked before use; no app-state/auth data leaves the app. DNS preflight is not connection pinning and does not cover WebView requests. No `BuildContext` inside the pure URL classifier. No duplicated link-routing logic in UI. Respect root code DNA header and comments policy. Add tests under `test/resource_viewer/`; do not run them mid-plan.
