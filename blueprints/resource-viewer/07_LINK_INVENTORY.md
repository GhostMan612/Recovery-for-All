# 07 — Current resource link inventory and migration boundaries

**Source audit:** Local `lib/` source search, 2026-10-12. This inventory records observed callsites and dispositions; it does not claim the app's entire runtime navigation graph or all URL construction is statically discoverable.

| Caller | Current source behavior | Disposition / status |
|---|---|---|
| Twelve Steps dashboard tile | Pushes `StepsViewerScreen` internally | Keep unchanged. |
| Literature link inside each expanded step | `steps_viewer_screen.dart` calls `ResourceRouter.open` with `ResourceRequest.aaStep(step.number)` | Routed through the explicit per-step PDF registry. Official endpoint response evidence remains unsubstantiated in the reviewed tree; release blocked. |
| Literature Library entries | `literature_library_screen.dart` calls `ResourceRouter.open` with a stable screen-level `sourceId` | Migrated; policy chooses PDF/HTML/system/blocked. Link-health UX must remain covered by the final suite. |
| Community Resources entries | `community_resources_screen.dart` calls `ResourceRouter.open` with a stable screen-level `sourceId` | Migrated; policy chooses route. Other community actions remain distinct. |
| Imported workbook PDFs | `custom_workbook_screen.dart` opens a caller-owned local path in the shared native `ResourcePdfScreen`/`PdfDocumentView` path | Preserve local ownership; never sweep or delete the imported source. |
| Dashboard SOS crisis website | `dashboard_screen.dart` opens 988 Lifeline externally | Safety-critical escape remains external; exclude from this viewer migration and audit separately. |
| SOS and crisis hotline telephone/SMS | `dashboard_screen.dart`, `sos_notification_service.dart`, and `chatbot_screen.dart` use native `tel:`/`sms:` handlers | Preserve native behavior; never route into WebView. |
| Onboarding FastTrackerMN directory | `onboarding_screen.dart` opens `fasttrackermn.org` externally | Recovery-service directory, but outside the two migrated screens. Keep explicit external behavior pending a scoped UX/allowlist review; nearby county phone links remain native. |
| Meeting directions and Zoom | `meeting_map_screen.dart` opens Google Maps directions and meeting/Zoom links externally | Preserve maps/deep-link handoff; meeting joins are not generic reading material. |
| Sober-housing phone/directions | `sober_housing_locator.dart` uses native `tel:` and `geo:` handlers | Preserve native actions. |
| Wellbriety flyers and online rooms | `wellbriety_circles_screen.dart` opens provider flyer images/pages and online-room links externally | Keep explicit external handoff; these include image/meeting-join experiences and were not silently changed. Revisit only with a deliberate route and host-policy decision. |
| Seventh Tradition donation links | `seventh_tradition_screen.dart` launches the selected external payment/donation destination | Keep external; payments are not embedded in this reader scope. |
| Repository spec and legal/security docs | `settings_screen.dart` opens GitHub pages externally | Keep browser behavior; project/legal navigation is not a built-in recovery document. |
| Other literal/dynamic URL launchers | Repository source search also found the callsites above; URL launches are not limited to `launchUrl` identifiers | Review future callsites individually; do not apply a bulk launcher rewrite. |

## Registry and policy source

- `lib/data/recovery_literature.dart` and `lib/data/recovery_resources.dart` provide registered URL inputs to `ResourcePolicy`; the policy compares exact origins, not host substrings.
- `lib/core/resources/aa_step_resources.dart` supplies the separate explicit Step 1–12 candidate URL map. The checked-in candidate manifest remains `validated: false`, and no durable live-response record was present in this review.
- `lib/services/resource_link_health.dart` remains the existing availability service. A `HEAD` status is not proof of a PDF payload.
- `lib/data/worksheets_registry.dart` identifies worksheet content and is not a PDF registry.

## Scope boundary

The Literature Library and Community Resources migrations are present in source. The other entries above have explicit dispositions rather than being treated as accidental gaps. Do not migrate them just to make this list shorter: SOS, dialing, maps, meeting joins, payments, and provider-specific flyer flows need their own user-action and failure-policy review.
