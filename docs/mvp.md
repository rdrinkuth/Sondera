# Sondera MVP: Features and Scope

*Updated 2026-11-11 (v2: adds a friends-first social layer). Web app, Goodreads-shaped, with an action loop as the differentiator. Useful solo first, social from day one.*

## Product in one line
A Goodreads-style library for self-improvement content (YouTube, articles, books) where every item ends in a reflection, an action, and an outcome, and where you can see what your friends got out of the same content.

## Core loop
Add item -> Reflect (short) -> Get 1-3 AI actions -> Commit to one -> Check in -> Record outcome (Tried / Stuck / Dropped) -> Optionally share with friends

## MVP features (must ship)

### Personal loop
1. **Account**: sign up and log in (email + password or magic link), with a unique username and display name.
2. **Add item**: paste a YouTube or article URL. App fetches title, source, thumbnail, and transcript or article text. Books are added manually or via Open Library search. All types normalize to one `Item` format.
3. **Shelves**: Queue, In progress, Done. Library page with filters by shelf, type, and outcome.
4. **Reflection (required)**: 2-3 sentence limit, with 2-3 prompts to pick from (e.g., "Where does this show up in your life this week?"). Needed before actions are generated. If the reflection is vague, the AI asks one follow-up.
5. **AI action generation**: from transcript/text plus the reflection, produce 1-3 actions in if-then form ("When X, I will Y") with a short backup plan for the likely obstacle. User can regenerate or mark "too vague" (stored as feedback).
6. **Commit**: pick one action and a time window.
7. **Check-in**: email at the committed time, with one-click Done / Not yet / Skip. Also an in-app Today page listing open actions. Responses set the outcome. Optional one-line note.
8. **Outcome on every item**: Tried it / Stuck with it / Dropped it, shown on the library and item page next to the star rating.
9. **Soft throttle**: if 2+ actions are open, adding a new item shows a nudge ("finish or drop these first"). Warns, does not block.
10. **Personal stats page**: items added vs. acted on, action rate, stick rate, breakdown by source type and creator/topic.

### Social layer (friends-first, light)
11. **Visibility per entry**: each entry's reflection, action, and outcome are **Private by default**, or can be shared with **Friends**. (No "Public" option in MVP, which avoids moderation and keeps reflections honest.)
12. **Friends**: follow by username or invite link. Simple one-way follow, no approval flow.
13. **Item page: "What people got out of this"**: for any item, shows reflections, actions, and outcomes your friends chose to share, plus a count like "2 friends tried it, 1 stuck." The core Goodreads-style moment.
14. **Friends activity feed**: simple chronological list of shared updates (added, reflected, acted, outcome). No algorithm.
15. **Profile page**: username, shelves you've shared, your stats (shared items only).

## Not in MVP (explicitly deferred)
- Public reflections, public profiles, discovery of strangers, user search beyond username
- Comments, likes, reactions, notifications for social activity
- Outcome-based recommendations ("people who acted on this stuck with it")
- Content-finding agent
- Goodreads CSV import (first post-MVP add, since it seeds the library)
- Browser extension / share target / mobile app
- Podcasts, payments, notifications beyond email

## Data model (draft — db/schema.sql is the reference)
- **User**: id, email, username, display_name, created_at
- **Item**: id, type (youtube/article/book), url, title, creator, source_text, metadata
- **Entry** (user-item): id, user_id, item_id, shelf, star_rating (optional), outcome, visibility (private/friends, default private), added_at
- **Reflection**: id, entry_id, prompt, text
- **Action**: id, entry_id, if_then_text, backup_plan, status (suggested/committed/done/skipped), due_at, feedback
- **CheckIn**: id, action_id, sent_at, response, note
- **Follow**: follower_id, followee_id, created_at
- **Invite**: id, inviter_id, code, used_by, created_at

## Privacy and content rules
- Everything is private unless the user shares it, per entry.
- Never show other users' `source_text` (transcripts or article text). Show title, link, and thumbnail only.
- Friends only see what was explicitly shared; unsharing hides it immediately.

## Build order
1. Auth, DB schema (including visibility and follow tables from the start), health check
2. Add item + ingestion (YouTube transcript, article extraction, manual book)
3. Library and shelves UI
4. Reflection + AI action generation (prompt quality is the make-or-break piece)
5. Commit + check-in (email scheduling) + Today page
6. Outcomes, throttle nudge, personal stats page
7. Social: usernames, follow/invite, visibility controls, item page with shared reflections, friends feed, profile

Rough estimate: 5-7 weeks at 20+ hrs/week with agentic coding. Treat as a guess until step 2 is done. Steps 1-6 are usable solo; step 7 needs a few friends to test.

## Success criteria
- Ryan uses it for 2 weeks on his own content
- Most added items get a reflection and a committed action
- At least some check-ins end in "Tried it"; "too vague" feedback trends down
- 5-10 friends invited; at least some share reflections and read each other's
- Signal to watch: do people open the item page to see what friends got out of it?

## Assumptions to confirm
- Check-ins by email (cheapest nudge); SMS or push later
- Reflection is required, not optional (loosen if it gets skipped)
- Social is friends-only in MVP (no public content) because it avoids the empty-network problem and moderation work
- Stack is settled: see CLAUDE.md (FastAPI + React + Supabase Postgres/Auth)
- YouTube transcript and article fetching need fallbacks (no captions, paywalls: "paste text" option). YouTube often blocks transcript requests from cloud server IPs, so expect the fallback to be used in production.
