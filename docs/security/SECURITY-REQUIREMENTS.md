# Security Requirements - McCleaner.app (macOS)
Swift package, signed + notarized macOS cleaner; deletes user files so safety matters more than server security.

## Data classification
| Data | Class | Where |
|---|---|---|
| User files scanned locally | user data | never uploaded (verify) |
| Licence state | internal | local + Stripe backend |

## Baseline requirements
- Secrets only in env/files (chmod 600, git-ignored); no keys in front-end; no default credentials.
- Server-side authorization for every privileged action; fail closed.
- Rate limit public/costly endpoints (shared store on serverless); spend caps on paid APIs.
- Privacy: consent before tracking, minimal data, deletion path; run legal-launch-preflight.
See INVENTORY.md for auto-detected routes/env/tables.
