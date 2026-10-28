# Threat Model - McCleaner.app (macOS)
| ID | Threat | Mitigation | Test |
|---|---|---|---|
| T1 | Deleting system/user-critical files | allow-list of cleanable locations, dry-run/confirm, move to Trash where possible | tests on protected paths |
| T2 | Tampered update/download | signed + notarized, HTTPS download | spctl check |
| T3 | Licence bypass | server-side verification via payment backend | manual test |
| T4 | Privilege misuse | least privilege, no unneeded entitlements | entitlement review |
