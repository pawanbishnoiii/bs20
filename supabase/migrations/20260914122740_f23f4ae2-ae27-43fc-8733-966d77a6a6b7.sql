DO $$
BEGIN
  IF to_regclass('public.study_sessions') IS NOT NULL AND to_regclass('public.subjects') IS NOT NULL THEN
    ALTER TABLE public.study_sessions DROP CONSTRAINT IF EXISTS study_sessions_subject_id_fkey;
    ALTER TABLE public.study_sessions ADD CONSTRAINT study_sessions_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.timetable_blocks') IS NOT NULL AND to_regclass('public.subjects') IS NOT NULL THEN
    ALTER TABLE public.timetable_blocks DROP CONSTRAINT IF EXISTS timetable_blocks_subject_id_fkey;
    ALTER TABLE public.timetable_blocks ADD CONSTRAINT timetable_blocks_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.sessions') IS NOT NULL AND to_regclass('public.subjects') IS NOT NULL THEN
    ALTER TABLE public.sessions DROP CONSTRAINT IF EXISTS sessions_subject_id_fkey;
    ALTER TABLE public.sessions ADD CONSTRAINT sessions_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;
  END IF;
  IF to_regclass('public.targets') IS NOT NULL AND to_regclass('public.subjects') IS NOT NULL THEN
    ALTER TABLE public.targets DROP CONSTRAINT IF EXISTS targets_subject_id_fkey;
    ALTER TABLE public.targets ADD CONSTRAINT targets_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE SET NULL;
  END IF;
END $$;

ALTER TABLE IF EXISTS public.timetable_blocks ADD COLUMN IF NOT EXISTS week_parity text NOT NULL DEFAULT 'all';

DO $$
BEGIN
  IF to_regclass('public.timetable_blocks') IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'timetable_blocks_week_parity_check'
  ) THEN
    ALTER TABLE public.timetable_blocks ADD CONSTRAINT timetable_blocks_week_parity_check CHECK (week_parity IN ('all', 'odd', 'even'));
  END IF;
END $$;

ALTER TABLE IF EXISTS public.subject_catalog ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.subjects ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.targets ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.study_sessions ADD COLUMN IF NOT EXISTS chapter text;

CREATE TABLE IF NOT EXISTS public.reading_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('newspaper','magazine')),
  log_date date NOT NULL DEFAULT (now()::date),
  minutes integer NOT NULL DEFAULT 15,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, log_date)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.reading_logs TO authenticated;
GRANT ALL ON public.reading_logs TO service_role;

ALTER TABLE public.reading_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users manage own reading logs" ON public.reading_logs;
CREATE POLICY "Users manage own reading logs" ON public.reading_logs
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS reading_logs_updated_at ON public.reading_logs;
CREATE TRIGGER reading_logs_updated_at BEFORE UPDATE ON public.reading_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

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

GRANT SELECT, INSERT, UPDATE, DELETE ON public.reading_checkins TO authenticated;
GRANT ALL ON public.reading_checkins TO service_role;

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