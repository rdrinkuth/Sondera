# Sondera

Goodreads-style web app for self-improvement content (YouTube videos, articles, books). Every item ends in a reflection, an action, and an outcome, and you can see what your friends got out of the same content.

Full spec: `docs/mvp.md`. Read it before planning any feature.

## Core loop
Add item -> Reflect (2-3 sentences) -> Get 1-3 AI actions ("When X, I will Y" + backup plan) -> Commit to one -> Email check-in -> Outcome (Tried / Stuck / Dropped) -> Optionally share with friends

## Stack
- **Backend:** Python, FastAPI, SQLAlchemy 2.0, Alembic, Pydantic
- **Database + auth:** Supabase (Postgres + Supabase Auth). FastAPI verifies the Supabase JWT on protected routes.
- **Frontend:** React + Vite + TypeScript, Tailwind, shadcn/ui
- **AI:** LLM API called only from the backend. Prompts live in `backend/app/prompts/`.
- **Ingestion:** `youtube-transcript-api`, `trafilatura` (articles), Open Library API (books). Always provide a "paste text" fallback.
- **Email:** Resend. A scheduled job runs every 10-15 min and sends check-ins that are due. No Celery or Redis.
- **Hosting:** Vercel (frontend), Render or Railway (backend)

## Repo layout
```
/backend
  app/
    main.py        # FastAPI app, routers mounted here
    routers/       # one file per resource (items, entries, reflections, actions...)
    models/        # SQLAlchemy models
    schemas/       # Pydantic request/response models
    services/      # ingestion, AI, email logic
    prompts/       # LLM prompt templates
  alembic/
  tests/
/frontend
  src/
    pages/
    components/
    lib/api.ts     # all calls to the backend go through here
/db
  schema.sql       # reference schema (Alembic migrations should match it)
/docs
  mvp.md           # product spec
  progress.md      # what's done, what's next (update at end of each session)
```

## Commands
- Backend dev: `cd backend && uvicorn app.main:app --reload`
- Backend tests: `cd backend && pytest`
- New migration: `cd backend && alembic revision --autogenerate -m "msg"` then `alembic upgrade head`
- Frontend dev: `cd frontend && npm run dev`

## Data model (summary, see docs/mvp.md and db/schema.sql for details)
User, Item, Entry (user-item: shelf, rating, outcome, visibility), Reflection, Action, CheckIn, Follow, Invite.
Visibility is `private` by default or `friends`. Never expose another user's `source_text`.

## Build order
1. Scaffolding, health check, auth, full DB schema (including visibility + follow tables)
2. Add item + ingestion
3. Library + shelves UI
4. Reflection + AI action generation
5. Commit + email check-ins + Today page
6. Outcomes, throttle nudge, stats page
7. Social: follow/invite, visibility controls, item page with friends' reflections, feed, profile

Work on one step at a time. Check `docs/progress.md` to see where we are.

## How to work with me
- I'm a CS student learning as I build. Explain how pieces connect before writing code, and explain non-obvious decisions in plain English.
- Keep changes small: one feature or endpoint per task. Don't touch unrelated files.
- Plan before coding anything bigger than a one-line fix. Wait for my approval on the plan.
- Write a pytest test for every new endpoint and run it before saying you're done.
- Tell me how to test the change myself (Swagger URL, UI steps).
- At the end of a task, update `docs/progress.md` and suggest a commit message.
- If something in the spec is unclear, ask instead of guessing.

## Rules
- Never commit `.env`, API keys, or secrets. Use `.env.example` for placeholders.
- Use type hints in Python and strict TypeScript.
- Don't add new dependencies without telling me why.
