---
name: backend-mastery
description: Expert patterns for backend server development across Ktor, Go net/http, Node/Express, Rails, Django, FastAPI, Spring — routing, middleware, authentication, background jobs, connection pooling, error handling. Auto-activates on server framework files.
allowed-tools: Read, Grep, WebFetch
paths: "**/build.gradle*,**/pom.xml,**/go.mod,**/requirements.txt,**/Gemfile,**/routes/**,**/controllers/**,**/services/**,**/middleware/**"
---

# backend-mastery — Backend expert knowledge

## What this covers
Framework-idiomatic patterns for request-response, middleware, error handling, and background processing. Ensures code follows how the framework WANTS the problem solved.

## Core principle
**Layer discipline.** Business logic in services, not routes. Errors handled centrally, not per-handler. Resources always closed.

## Key patterns (2026)

### Express 5 — Native async (no wrappers)

```js
// ❌ BEFORE: Express 4 async wrapper boilerplate
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);
app.get('/users', asyncHandler(async (req, res) => { ... }));

// ✅ AFTER: Express 5 native async
app.get('/users', async (req, res) => {
  const users = await User.find();
  res.json(users);
});
// Errors auto-forwarded to centralized error middleware
```

- Express 5 auto-catches promise rejections — no `express-async-errors` needed
- Centralized error middleware: `(err, req, res, next)` handles all errors

### FastAPI — Dependency injection for layered security

```python
# ✅ Layered security via Depends()
from fastapi import Depends, HTTPException

async def get_current_user(token: str = Depends(oauth2_scheme)):
    user = await verify_token(token)
    if not user:
        raise HTTPException(status_code=401)
    return user

@app.get("/protected")
async def protected_route(user = Depends(get_current_user)):
    return {"user": user}
```

### Django 5 — Security middleware

```python
# settings.py — security headers via middleware
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    # ... HSTS, X-Frame-Options, CSP
]
```

## Bypass signals to detect

- Business logic in route handlers (should be in services)
- DB queries in controllers (should be behind repository)
- Raw SQL string concat (should be parameterized)
- `catch (Exception e) { }` swallowing errors
- Unclosed resources (connections, file handles, streams)
- `try/catch` in every async handler (Express 5 handles this)
- `mark_safe()` with user input (Django XSS vector)

## Anti-patterns

- **Error swallowing** — `catch {}` with no logging or re-throw
- **Business logic in handlers** — routes should delegate to services
- **Missing input validation** — validate at the boundary (Zod, Pydantic, Django forms)
- **No rate limiting** — auth endpoints MUST be rate-limited
- **Missing security headers** — Helmet (Express), SecurityMiddleware (Django)

## How to verify

- [ ] Centralized error handling middleware present?
- [ ] Business logic in services, not route handlers?
- [ ] Input validated at the boundary (Zod/Pydantic/Django forms)?
- [ ] Resources closed (try-with-resources, `use`, `defer`, context managers)?
- [ ] Rate limiting on auth endpoints?
- [ ] Security headers configured (HSTS, CSP, X-Frame-Options)?
- [ ] Express 5: no async wrapper boilerplate (native async)?

## When triggered

- `explorer` agent parallel dispatch when backend files detected
- Task mentions endpoint / route / handler / middleware / service / job / worker
- `paths` glob auto-activates on server framework files

## References

- Express 5 async — https://expressjs.com/en/guide/migrating-5.html
- FastAPI security — https://fastapi.tiangolo.com/tutorial/security/
- Django security — https://docs.djangoproject.com/en/5.1/topics/security/
- OWASP Top 10 — https://owasp.org/www-project-top-ten/
