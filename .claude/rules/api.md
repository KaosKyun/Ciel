---
paths:
  - "**/api/**"
  - "**/routes/**"
  - "**/*Controller*"
  - "**/*Endpoint*"
  - "**/*Route*"
---

## API design rules

- Contract-first: define types/interfaces before implementation
- Validate all inputs at boundary (never trust caller)
- Return structured errors: `{error: {code, message, details}}`
- Pagination on list endpoints (cursor preferred over page/offset)
- Rate limiting on all public endpoints
- All endpoints must be observable (logging, metrics, tracing)
- Version API via header (Accept: application/vnd.api.v2+json) not URL
