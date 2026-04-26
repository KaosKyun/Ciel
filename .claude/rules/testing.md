---
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/__tests__/**"
  - "**/test/**"
  - "**/tests/**"
---

## Testing rules

- Follow the test pyramid: 70% unit, 20% integration, 10% E2E
- Test behavior, not implementation
- DAMP over DRY in tests (descriptive, self-contained tests)
- One assertion concept per test
- Name tests descriptively: "does X when Y"
- Bug fixes MUST include a reproduction test that failed before the fix
- Use Arrange-Act-Assert pattern
