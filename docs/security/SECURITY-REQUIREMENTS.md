# Security Requirements
## Data classification
| Data | Class (public/internal/PII/secret) | Where stored | Retention |
## Authentication & authorization
- Auth method, password policy, 2FA, session lifetime; server-side authz on every route; tenant isolation (RLS)
## Input/output
- Validation (schema) on all inputs; output encoding; upload type/size limits
## Secrets & config
- No keys in front-end; env vars list; rotation plan; no default credentials
## Availability & cost
- Rate limits per public/costly route; spend caps and loop guards for AI/paid APIs
## Privacy & legal
- GDPR basis, consent, deletion/export, cookie/analytics opt-in, messaging consent
## Compliance targets
- OWASP ASVS level: ; logging/audit requirements:
