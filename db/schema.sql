-- Sondera MVP schema (PostgreSQL 13+ / Supabase)
-- Matches docs/mvp.md (v2): personal loop + friends-first social layer.
-- Reference schema: Alembic migrations should produce the same tables.

BEGIN;

-- ---------- Enums ----------
CREATE TYPE item_type        AS ENUM ('youtube', 'article', 'book');
CREATE TYPE shelf            AS ENUM ('queue', 'in_progress', 'done');
CREATE TYPE outcome          AS ENUM ('tried', 'stuck', 'dropped');
CREATE TYPE visibility       AS ENUM ('private', 'friends');
CREATE TYPE action_status    AS ENUM ('suggested', 'committed', 'done', 'skipped');
CREATE TYPE action_feedback  AS ENUM ('good', 'too_vague', 'not_relevant');
CREATE TYPE checkin_response AS ENUM ('done', 'not_yet', 'skipped');

-- ---------- Users ----------
-- Supabase Auth handles sign-up, login, and passwords (stored in auth.users).
-- This table is the app's profile for each user. id = the Supabase auth user id
-- (the "sub" claim in the JWT), so there's no password column here.
CREATE TABLE users (
    id            UUID PRIMARY KEY,           -- = auth.users.id from Supabase
    email         TEXT NOT NULL,
    username      TEXT NOT NULL,
    display_name  TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT username_format CHECK (username ~ '^[a-z0-9_]{3,30}$')
);
CREATE UNIQUE INDEX users_email_key    ON users (lower(email));
CREATE UNIQUE INDEX users_username_key ON users (username);

-- ---------- Items (shared across users) ----------
CREATE TABLE items (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type          item_type NOT NULL,
    url           TEXT,                        -- normalized; NULL for manually added books
    external_id   TEXT,                        -- YouTube video id, Open Library id, etc.
    title         TEXT NOT NULL,
    creator       TEXT,
    thumbnail_url TEXT,
    source_text   TEXT,                        -- transcript / article text. NEVER shown to other users.
    metadata      JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX items_url_key           ON items (url) WHERE url IS NOT NULL;
CREATE UNIQUE INDEX items_type_external_key ON items (type, external_id) WHERE external_id IS NOT NULL;

-- ---------- Entries (a user's relationship to an item) ----------
CREATE TABLE entries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    item_id     UUID NOT NULL REFERENCES items (id) ON DELETE RESTRICT,
    shelf       shelf NOT NULL DEFAULT 'queue',
    star_rating SMALLINT CHECK (star_rating BETWEEN 1 AND 5),
    outcome     outcome,                       -- set by check-ins or manually
    visibility  visibility NOT NULL DEFAULT 'private',
    added_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, item_id)
);
CREATE INDEX entries_user_shelf_idx ON entries (user_id, shelf);
CREATE INDEX entries_item_idx       ON entries (item_id);   -- for "what people got out of this"

-- ---------- Reflections (one per entry) ----------
CREATE TABLE reflections (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id          UUID NOT NULL UNIQUE REFERENCES entries (id) ON DELETE CASCADE,
    prompt            TEXT NOT NULL,
    text              TEXT NOT NULL CHECK (char_length(text) BETWEEN 1 AND 600),
    followup_question TEXT,                    -- AI follow-up if the reflection was vague
    followup_answer   TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Actions (AI-suggested, user-committed) ----------
CREATE TABLE actions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    entry_id     UUID NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
    if_then_text TEXT NOT NULL,                -- "When X, I will Y"
    backup_plan  TEXT,                         -- coping plan for the likely obstacle
    status       action_status NOT NULL DEFAULT 'suggested',
    feedback     action_feedback,              -- user rating of action quality
    committed_at TIMESTAMPTZ,
    due_at       TIMESTAMPTZ,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT committed_has_due CHECK (status <> 'committed' OR due_at IS NOT NULL)
);
CREATE INDEX actions_entry_idx    ON actions (entry_id);
CREATE INDEX actions_open_due_idx ON actions (due_at) WHERE status = 'committed';

-- ---------- Check-ins ----------
CREATE TABLE check_ins (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_id    UUID NOT NULL REFERENCES actions (id) ON DELETE CASCADE,
    token        TEXT NOT NULL UNIQUE,         -- random token for one-click email links
    sent_at      TIMESTAMPTZ,
    responded_at TIMESTAMPTZ,
    response     checkin_response,
    note         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX check_ins_action_idx  ON check_ins (action_id);
CREATE INDEX check_ins_pending_idx ON check_ins (sent_at) WHERE responded_at IS NULL;

-- ---------- Social: follows and invites ----------
CREATE TABLE follows (
    follower_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    followee_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (follower_id, followee_id),
    CHECK (follower_id <> followee_id)
);
CREATE INDEX follows_followee_idx ON follows (followee_id);

CREATE TABLE invites (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    code       TEXT NOT NULL UNIQUE,
    used_by    UUID REFERENCES users (id) ON DELETE SET NULL,
    used_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------- Keep entries.updated_at fresh ----------
CREATE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER entries_set_updated_at
    BEFORE UPDATE ON entries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;

-- ---------- Example: what friends shared about an item (for the item page) ----------
-- SELECT u.username, e.outcome, r.text, a.if_then_text
-- FROM entries e
-- JOIN users u            ON u.id = e.user_id
-- JOIN follows f          ON f.followee_id = e.user_id AND f.follower_id = :viewer_id
-- LEFT JOIN reflections r ON r.entry_id = e.id
-- LEFT JOIN actions a     ON a.entry_id = e.id AND a.status IN ('committed','done')
-- WHERE e.item_id = :item_id AND e.visibility = 'friends';
