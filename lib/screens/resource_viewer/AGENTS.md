# AGENTS.md — Internal reader screens

**Status: implementation present; device validation pending.** Existing files include `resource_pdf_screen.dart`, `resource_web_screen.dart`, `resource_toolbar.dart`, and shared `pdf_document_view.dart`. Review their integration and ownership contracts before modifying them.

Reuse Material 3 app theme and current shared loading/error primitives; push routes above the dashboard rather than becoming another destination. Preserve all step/worksheet/workbook state. No own URL security policy, no direct recovery DB references, no automatic browser fallback, no arbitrary script channels, no swallowed error blank screens. Native PDFs from approved temporary file paths; WebView only for approved HTML links. Source-level host tests do not replace low-end Android and release-device checks. Root `AGENTS.md` rules override this file.
