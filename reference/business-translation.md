# Translation guide: technical → business impact

Apply in Phase 2, when writing the release and roadmap prose.

Write the output in the configured `outputLanguage`, with correct orthography and diacritics
(never strip accents).

## Rules

1. **Lead with impact, not mechanism.** Say what changed for the company/customer, not how it was
   done technically.
2. **Quantify when the card allows.** Pull real numbers from the descriptions ($/%/time).
3. **Zero jargon in the main prose.** No internal tool names, infra acronyms, or implementation
   terms. If a term is unavoidable, translate it in parentheses in plain language. Jargon only
   survives in the traceability appendix.
4. **Group by business theme.** Use `labels`/`components` first; fall back to keywords in the
   summary/description.
5. **One "why it matters" sentence** per theme: the benefit to the company/customer, not the team.
6. **Tone:** executive, concise, confident.
7. **Never invent impact.** A card with no evidence of benefit → a "Review" note for the owner to decide.

## Seed themes (adjust per board)

| Theme | Emoji | Catches cards about… |
|-------|-------|----------------------|
| Cost / Efficiency | 💰 | spend reduction, resource optimization, automation that saves work |
| Security & Compliance | 🔒 | access control, data protection, vulnerability fixes, auditing |
| Reliability | 🛡️ | stability, failure recovery, incident reduction |
| Performance | ⚡ | speed, latency, capacity, response time |
| Platform / Experience | 🧱 | foundations, new capabilities, workflow improvements for users/teams |

These themes are a starting point. Adapt the names to the board's vocabulary.

Fallback heuristic: if no label matches, classify by the first keyword in the summary; if still
ambiguous, pick the theme of the *predominant benefit* (e.g. a change that cuts CPU usage is
Performance, but if the card frames it as savings, it's Cost).

## Examples (technical → business)

- "Standardize cloud cost tagging" → "We made infrastructure cost reports simpler and more reliable."
- "Configure a shared cookie domain across subdomains" → "Login now works smoothly across the
  product's different addresses."
- "Add an index that resolves CPU at 90%" → "We removed a bottleneck that was overloading the
  database, making queries faster and the system more stable."
