BEGIN;

ALTER TABLE IF EXISTS public.subjects
  ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE IF EXISTS public.targets
  ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.chapter_learning_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  chapter_name text NOT NULL,
  review_stage smallint NOT NULL DEFAULT 0,
  next_review_at timestamptz NOT NULL DEFAULT (now() + interval '1 day'),
  last_studied_at timestamptz,
  reading_minutes integer NOT NULL DEFAULT 0,
  revision_minutes integer NOT NULL DEFAULT 0,
  class_minutes integer NOT NULL DEFAULT 0,
  practice_minutes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT chapter_learning_state_owner_subject_chapter_key
    UNIQUE (user_id, subject_id, chapter_name),
  CONSTRAINT chapter_learning_state_name_check
    CHECK (char_length(btrim(chapter_name)) BETWEEN 1 AND 240),
  CONSTRAINT chapter_learning_state_stage_check CHECK (review_stage BETWEEN 0 AND 4),
  CONSTRAINT chapter_learning_state_minutes_check CHECK (
    reading_minutes >= 0 AND revision_minutes >= 0 AND
    class_minutes >= 0 AND practice_minutes >= 0
  )
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.chapter_learning_state TO authenticated;
GRANT ALL ON public.chapter_learning_state TO service_role;

CREATE TABLE IF NOT EXISTS public.reading_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reading_date date NOT NULL DEFAULT CURRENT_DATE,
  newspaper_done boolean NOT NULL DEFAULT false,
  magazine_done boolean NOT NULL DEFAULT false,
  newspaper_minutes integer NOT NULL DEFAULT 0,
  magazine_minutes integer NOT NULL DEFAULT 0,
  newspaper_target_minutes integer NOT NULL DEFAULT 30,
  magazine_target_minutes integer NOT NULL DEFAULT 20,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT reading_checkins_owner_date_key UNIQUE (user_id, reading_date)
);

ALTER TABLE public.reading_checkins
  ADD COLUMN IF NOT EXISTS newspaper_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS magazine_minutes integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS newspaper_target_minutes integer NOT NULL DEFAULT 30,
  ADD COLUMN IF NOT EXISTS magazine_target_minutes integer NOT NULL DEFAULT 20;

DO $constraints$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.reading_checkins'::regclass
      AND conname = 'reading_checkins_minutes_check'
  ) THEN
    ALTER TABLE public.reading_checkins
      ADD CONSTRAINT reading_checkins_minutes_check CHECK (
        newspaper_minutes >= 0 AND magazine_minutes >= 0 AND
        newspaper_target_minutes BETWEEN 1 AND 1440 AND
        magazine_target_minutes BETWEEN 1 AND 1440
      );
  END IF;
END
$constraints$;

CREATE OR REPLACE FUNCTION public.set_chronodeck_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $function$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS set_chapter_learning_state_updated_at ON public.chapter_learning_state;
CREATE TRIGGER set_chapter_learning_state_updated_at
BEFORE UPDATE ON public.chapter_learning_state
FOR EACH ROW EXECUTE FUNCTION public.set_chronodeck_updated_at();

DROP TRIGGER IF EXISTS set_reading_checkins_updated_at ON public.reading_checkins;
CREATE TRIGGER set_reading_checkins_updated_at
BEFORE UPDATE ON public.reading_checkins
FOR EACH ROW EXECUTE FUNCTION public.set_chronodeck_updated_at();

ALTER TABLE public.chapter_learning_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reading_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "chapter_state_select_own" ON public.chapter_learning_state;
CREATE POLICY "chapter_state_select_own" ON public.chapter_learning_state
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "chapter_state_insert_own" ON public.chapter_learning_state;
CREATE POLICY "chapter_state_insert_own" ON public.chapter_learning_state
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "chapter_state_update_own" ON public.chapter_learning_state;
CREATE POLICY "chapter_state_update_own" ON public.chapter_learning_state
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "chapter_state_delete_own" ON public.chapter_learning_state;
CREATE POLICY "chapter_state_delete_own" ON public.chapter_learning_state
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "reading_checkins_select_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_select_own" ON public.reading_checkins
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "reading_checkins_insert_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_insert_own" ON public.reading_checkins
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "reading_checkins_update_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_update_own" ON public.reading_checkins
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "reading_checkins_delete_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_delete_own" ON public.reading_checkins
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS chapter_state_due_idx
  ON public.chapter_learning_state (user_id, next_review_at);
CREATE INDEX IF NOT EXISTS chapter_state_subject_idx
  ON public.chapter_learning_state (user_id, subject_id);
CREATE INDEX IF NOT EXISTS reading_checkins_user_date_idx
  ON public.reading_checkins (user_id, reading_date DESC);

COMMIT;