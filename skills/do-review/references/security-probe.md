# Security Probe: False-Positive Filtering

False-positive filtering rules for security findings during high-risk review. Surface only findings with high confidence of real exploitability — theoretical risks and defense-in-depth gaps are not findings.

## Exclusion Rules

Drop findings matching these patterns unless specific context overrides:

1. Denial of service via resource exhaustion
2. Missing rate limiting in internal services
3. Memory consumption limits
4. Findings in test files, test fixtures, or mock data
5. Log spoofing or unsanitized log output (unless logging secrets or PII)
6. Memory safety issues in memory-safe languages (Rust, Go, Java, C#, Python)
7. Regex injection or ReDoS
8. Path-only SSRF without host or protocol control
9. Findings in documentation files (markdown, comments, examples)
10. Missing security hardening (CSP, HSTS, etc.) without an active exploit path
11. Theoretical race conditions without demonstrated impact
12. Outdated libraries without a known exploitable CVE
13. GitHub Actions workflow issues unless processing untrusted input (PR titles, issue bodies)
14. Developer-authored AI/LLM prompt templates (flag when untrusted user input flows into LLM calls at runtime)
15. Missing audit logging
16. CSRF in stateless APIs using token-based auth
17. Prototype pollution in non-JavaScript code

Downgrade to `follow_up` (do not drop):

- Non-security input validation without proven security impact

## Precedents

| Pattern | Verdict | Rationale |
| --- | --- | --- |
| React/Angular/Vue template output | SAFE | Auto-escaped; only flag when using explicit unsafe APIs (innerHTML binding, raw HTML insertion) |
| Environment variables and CLI flags | TRUSTED | Not attacker-controlled in standard deployments |
| UUIDs (v4) as identifiers | SAFE | Cryptographically random, not guessable |
| ORM parameterized queries | SAFE | Framework prevents SQL injection |
| Shell scripts in CI/CD with controlled inputs | SAFE | No untrusted user input flows into execution |
| bcrypt/scrypt/argon2 outputs | SAFE | Not reversible; do not flag as weak hashing |
| Container-scoped secrets (K8s secrets, Docker secrets) | SAFE | Scoped access, not exposed in code |
| Client-side JS auth/permission checks | OUT OF SCOPE | Server enforces; client checks are UX only |
| Notebook code execution (*.ipynb) | INHERENT | Code execution is the platform's purpose |
| Subtle web vulns (tabnabbing, XS-Leaks, prototype pollution, open redirects) | SKIP | Unless very high confidence with specific exploit path |
| GraphQL with depth/complexity limits | SAFE | DoS mitigated by existing limits |
| HTTPS-only cookies in production | SAFE | Do not flag missing Secure attribute in dev configs |

## Anti-Patterns

- Reporting findings matching exclusion rules without explicit override justification
- Flagging pre-existing vulnerabilities not worsened by the reviewed change
- Skipping category classification — every security finding must identify its attack vector
