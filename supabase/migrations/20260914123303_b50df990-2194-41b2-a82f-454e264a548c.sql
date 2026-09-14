BEGIN;

CREATE TABLE IF NOT EXISTS public.chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 240),
  position integer NOT NULL DEFAULT 0,
  difficulty smallint NOT NULL DEFAULT 3 CHECK (difficulty BETWEEN 1 AND 5),
  estimated_minutes integer NOT NULL DEFAULT 60 CHECK (estimated_minutes BETWEEN 5 AND 6000),
  total_units integer CHECK (total_units IS NULL OR total_units > 0),
  units_done integer NOT NULL DEFAULT 0 CHECK (units_done >= 0),
  first_pass_done boolean NOT NULL DEFAULT false,
  archived boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (subject_id, name)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chapters TO authenticated;
GRANT ALL ON public.chapters TO service_role;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
CREATE POLICY "chapters_own" ON public.chapters FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS chapters_user_subject_idx ON public.chapters (user_id, subject_id, position);

CREATE TABLE IF NOT EXISTS public.chapter_subtopics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 240),
  position integer NOT NULL DEFAULT 0,
  estimated_minutes integer NOT NULL DEFAULT 30 CHECK (estimated_minutes BETWEEN 5 AND 3000),
  first_pass_done boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (chapter_id, name)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.chapter_subtopics TO authenticated;
GRANT ALL ON public.chapter_subtopics TO service_role;
ALTER TABLE public.chapter_subtopics ENABLE ROW LEVEL SECURITY;
CREATE POLICY "chapter_subtopics_own" ON public.chapter_subtopics FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS chapter_subtopics_chapter_idx ON public.chapter_subtopics (chapter_id, position);

ALTER TABLE public.study_sessions
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS subtopic_id uuid REFERENCES public.chapter_subtopics(id) ON DELETE SET NULL;
ALTER TABLE public.targets
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL;
ALTER TABLE public.timetable_blocks
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL;
ALTER TABLE public.chapter_learning_state
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS last_recall smallint CHECK (last_recall IS NULL OR last_recall BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS recall_samples integer NOT NULL DEFAULT 0;
ALTER TABLE public.daily_study_plan_items
  ADD COLUMN IF NOT EXISTS chapter_id uuid REFERENCES public.chapters(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS subtopic_id uuid REFERENCES public.chapter_subtopics(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS pinned boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS public.session_outcomes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL,
  subtopic_id uuid REFERENCES public.chapter_subtopics(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('reading','revision','class','practice')),
  units_done integer CHECK (units_done IS NULL OR units_done >= 0),
  unit_label text,
  is_reread boolean NOT NULL DEFAULT false,
  recall_rating smallint CHECK (recall_rating IS NULL OR recall_rating BETWEEN 1 AND 5),
  revision_result text CHECK (revision_result IS NULL OR revision_result IN ('independent','partial','needs_review')),
  content_completed_pct smallint CHECK (content_completed_pct IS NULL OR content_completed_pct BETWEEN 0 AND 100),
  net_focus_minutes integer CHECK (net_focus_minutes IS NULL OR net_focus_minutes >= 0),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (session_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.session_outcomes TO authenticated;
GRANT ALL ON public.session_outcomes TO service_role;
ALTER TABLE public.session_outcomes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "session_outcomes_own" ON public.session_outcomes FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS session_outcomes_user_idx ON public.session_outcomes (user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.test_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.study_sessions(id) ON DELETE SET NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL,
  subtopic_id uuid REFERENCES public.chapter_subtopics(id) ON DELETE SET NULL,
  scope text NOT NULL DEFAULT 'chapter' CHECK (scope IN ('chapter','mixed','external')),
  questions_total integer NOT NULL CHECK (questions_total > 0),
  questions_attempted integer NOT NULL DEFAULT 0 CHECK (questions_attempted >= 0),
  questions_correct integer NOT NULL DEFAULT 0 CHECK (questions_correct >= 0),
  score numeric(6,2),
  duration_minutes integer CHECK (duration_minutes IS NULL OR duration_minutes >= 0),
  weak_topics text[] NOT NULL DEFAULT '{}',
  taken_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (questions_attempted <= questions_total AND questions_correct <= questions_attempted)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.test_attempts TO authenticated;
GRANT ALL ON public.test_attempts TO service_role;
ALTER TABLE public.test_attempts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "test_attempts_own" ON public.test_attempts FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS test_attempts_user_idx ON public.test_attempts (user_id, taken_at DESC);

CREATE TABLE IF NOT EXISTS public.online_classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL,
  title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 240),
  mode text NOT NULL DEFAULT 'recorded' CHECK (mode IN ('live','recorded')),
  url text,
  scheduled_at timestamptz,
  duration_minutes integer CHECK (duration_minutes IS NULL OR duration_minutes > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.online_classes TO authenticated;
GRANT ALL ON public.online_classes TO service_role;
ALTER TABLE public.online_classes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "online_classes_own" ON public.online_classes FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS online_classes_user_idx ON public.online_classes (user_id, scheduled_at);

CREATE TABLE IF NOT EXISTS public.class_progress (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.online_classes(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.study_sessions(id) ON DELETE SET NULL,
  watched_content_minutes integer NOT NULL DEFAULT 0 CHECK (watched_content_minutes >= 0),
  wall_clock_minutes integer NOT NULL DEFAULT 0 CHECK (wall_clock_minutes >= 0),
  playback_speed numeric(3,2) NOT NULL DEFAULT 1.00 CHECK (playback_speed BETWEEN 0.25 AND 4),
  completed boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.class_progress TO authenticated;
GRANT ALL ON public.class_progress TO service_role;
ALTER TABLE public.class_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "class_progress_own" ON public.class_progress FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS class_progress_user_idx ON public.class_progress (user_id, class_id);

CREATE TABLE IF NOT EXISTS public.study_recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  for_date date NOT NULL DEFAULT CURRENT_DATE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE,
  chapter_id uuid REFERENCES public.chapters(id) ON DELETE CASCADE,
  subtopic_id uuid REFERENCES public.chapter_subtopics(id) ON DELETE SET NULL,
  kind text NOT NULL CHECK (kind IN ('reading','revision','class','practice')),
  suggested_minutes integer NOT NULL CHECK (suggested_minutes BETWEEN 5 AND 480),
  score numeric(8,3) NOT NULL DEFAULT 0,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','started','scheduled','shortened','dismissed','done')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, for_date, kind, chapter_id, subtopic_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_recommendations TO authenticated;
GRANT ALL ON public.study_recommendations TO service_role;
ALTER TABLE public.study_recommendations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "study_recommendations_own" ON public.study_recommendations FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS study_recommendations_user_idx
  ON public.study_recommendations (user_id, for_date, score DESC);

DO $t$
DECLARE r record;
BEGIN
  FOR r IN SELECT unnest(ARRAY['chapters','chapter_subtopics','session_outcomes','test_attempts',
                               'online_classes','class_progress','study_recommendations']) AS t
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS set_%1$s_updated_at ON public.%1$s', r.t);
    EXECUTE format('CREATE TRIGGER set_%1$s_updated_at BEFORE UPDATE ON public.%1$s
                    FOR EACH ROW EXECUTE FUNCTION public.set_chronodeck_updated_at()', r.t);
  END LOOP;
END
$t$;

COMMIT;