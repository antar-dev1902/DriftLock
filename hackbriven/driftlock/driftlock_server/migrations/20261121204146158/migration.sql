BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "driftlock_mission" (
    "id" bigserial PRIMARY KEY,
    "ownerIdentifier" text NOT NULL,
    "sessionId" text NOT NULL,
    "startedAtUtc" timestamp without time zone NOT NULL,
    "summary" json NOT NULL
);

-- Indexes
CREATE UNIQUE INDEX "driftlock_mission_owner_session" ON "driftlock_mission" USING btree ("ownerIdentifier", "sessionId");


--
-- MIGRATION VERSION FOR driftlock
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('driftlock', '20261121204146158', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261121204146158', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260824182259319', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260824182259319', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20261015164015382', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20261015164015382', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260924105232991', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260924105232991', "timestamp" = now();


COMMIT;
