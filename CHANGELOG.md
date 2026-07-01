# Changelog

All notable changes to QlikNPrinting-CLI are documented here.

## 1.1.0 - 2026-07-02
Refactor for robustness and maintainability:

- **Fixed** `Get-NPUsers -Roles / -Groups / -Filters` — these switches previously
  called a helper by the wrong name and errored; they now enrich each user.
- **Fixed** `-TrustAllCerts` on PowerShell 7 (it previously threw before connecting).
- **Cross-version error handling** — API errors are now surfaced correctly on both
  Windows PowerShell 5.1 and PowerShell 7 (previously only `WebException` was caught).
- **Create operations now return the new object's id** — `POST` responses come back
  as HTTP 201 with an empty body and the id in the `Location` header; the module now
  surfaces this as `{ id; location }` (PowerShell 6.1+). Empty `PUT`/`DELETE` responses
  no longer emit a spurious "No results received" error.
- Functions no longer use `break` in place of `return`, so failures can no longer
  escape a caller's loop.
- `-Name` filtering now works on `Get-NPTasks`, `Get-NPReports` and `Get-NPApps`.
- **Many new functions** covering the documented public API: full create/update/delete
  for Users, Filters, Groups and Apps; Connections (including reload); task execution
  (`Start-NPTask`, `Get-NPTaskExecutions`); on-demand report generation; and audit.
- Source is split one-function-per-file under `src/` and loaded at import. Added a
  Pester test suite.
- Authenticode-signed with a current certificate; `.gitattributes` pins PowerShell
  files to CRLF so signatures survive git.

## 1.0.0.10
- Bug fix: added missing parameter.

## 1.0.0.9
- Bug fix: `ConvertTo-Json` depth defaults to 5.
- Minor improvements.

## 1.0.0.8
- Updated and aligned with the PowerShell Gallery.
- `Invoke-NPRequest`: added parameters with default values for the required `-NPE`
  query path parameters.
