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
