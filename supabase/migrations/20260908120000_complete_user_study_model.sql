-- Complete the chapter and compulsory-reading model left partially applied by
-- the earlier subject-catalog migration. Safe to run more than once.
ALTER TABLE IF EXISTS public.subjects
  ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE IF EXISTS public.targets
  ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS public.reading_checkins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reading_date date NOT NULL DEFAULT CURRENT_DATE,
  newspaper_done boolean NOT NULL DEFAULT false,
  magazine_done boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, reading_date)
);

ALTER TABLE public.reading_checkins ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reading_checkins_select_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_select_own" ON public.reading_checkins FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "reading_checkins_insert_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_insert_own" ON public.reading_checkins FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "reading_checkins_update_own" ON public.reading_checkins;
CREATE POLICY "reading_checkins_update_own" ON public.reading_checkins FOR UPDATE TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS reading_checkins_user_date_idx
  ON public.reading_checkins (user_id, reading_date DESC);
