-- Automatic next-day study plans, completion tracking, and daily scheduling.
-- Safe to run repeatedly from the Supabase/Lovable SQL editor.
BEGIN;

CREATE TABLE IF NOT EXISTS public.daily_study_plan_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_date date NOT NULL,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE,
  chapter_name text,
  session_kind text NOT NULL DEFAULT 'reading'
    CHECK (session_kind IN ('reading', 'revision', 'class', 'practice')),
  target_minutes integer NOT NULL CHECK (target_minutes BETWEEN 5 AND 1440),
  priority smallint NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 20),
  source text NOT NULL DEFAULT 'automatic'
    CHECK (source IN ('automatic', 'manual', 'timetable')),
  completed_at timestamptz,
  completed_session_id uuid REFERENCES public.study_sessions(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, plan_date, subject_id, chapter_name, session_kind)
);

ALTER TABLE public.daily_study_plan_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "daily_plan_select_own" ON public.daily_study_plan_items;
CREATE POLICY "daily_plan_select_own" ON public.daily_study_plan_items
  FOR SELECT TO authenticated USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "daily_plan_insert_own" ON public.daily_study_plan_items;
CREATE POLICY "daily_plan_insert_own" ON public.daily_study_plan_items
  FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "daily_plan_update_own" ON public.daily_study_plan_items;
CREATE POLICY "daily_plan_update_own" ON public.daily_study_plan_items
  FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "daily_plan_delete_own" ON public.daily_study_plan_items;
CREATE POLICY "daily_plan_delete_own" ON public.daily_study_plan_items
  FOR DELETE TO authenticated USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS daily_plan_user_date_idx
  ON public.daily_study_plan_items (user_id, plan_date, priority);
CREATE INDEX IF NOT EXISTS daily_plan_pending_idx
  ON public.daily_study_plan_items (plan_date, user_id) WHERE completed_at IS NULL;

CREATE OR REPLACE FUNCTION public.build_study_plan_for_user(
  p_user_id uuid,
  p_plan_date date DEFAULT (CURRENT_DATE + 1)
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  inserted_count integer := 0;
  fresh_count integer := 0;
BEGIN
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'user_id is required'; END IF;

  -- Rebuilding only replaces unfinished automatic rows; completed/manual work survives.
  DELETE FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date
    AND source = 'automatic' AND completed_at IS NULL;

  -- Up to five due chapters (roughly 70% of a seven-item plan).
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, c.subject_id, c.chapter_name, 'revision',
    GREATEST(25, LEAST(120, ROUND(COALESCE(s.weekly_target_hours, 3) * 60 / 7.0)::integer)),
    ROW_NUMBER() OVER (ORDER BY c.next_review_at, c.review_stage DESC)::smallint
  FROM public.chapter_learning_state c
  JOIN public.subjects s ON s.id = c.subject_id AND s.user_id = p_user_id
  WHERE c.user_id = p_user_id AND c.next_review_at < (p_plan_date + interval '1 day')
  ORDER BY c.next_review_at, c.review_stage DESC
  LIMIT 5
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS inserted_count = ROW_COUNT;

  -- Fill the remaining two slots with fresh syllabus chapters.
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, s.id, chapter.value, 'reading',
    GREATEST(25, LEAST(120, ROUND(COALESCE(s.weekly_target_hours, 3) * 60 / 7.0)::integer)),
    (inserted_count + ROW_NUMBER() OVER (ORDER BY s.created_at, chapter.ordinality))::smallint
  FROM public.subjects s
  CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(s.chapters, '[]'::jsonb))
    WITH ORDINALITY AS chapter(value, ordinality)
  LEFT JOIN public.chapter_learning_state c
    ON c.user_id = p_user_id AND c.subject_id = s.id AND c.chapter_name = chapter.value
  WHERE s.user_id = p_user_id AND c.id IS NULL
  ORDER BY s.created_at, chapter.ordinality
  LIMIT GREATEST(0, 7 - inserted_count)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS fresh_count = ROW_COUNT;
  inserted_count := inserted_count + fresh_count;

  -- A new account without chapter data still gets a subject-level target plan.
  IF inserted_count = 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
    SELECT p_user_id, p_plan_date, s.id, NULL, 'reading',
      GREATEST(25, LEAST(180, ROUND(COALESCE(t.daily_hours, s.weekly_target_hours / 7.0, 0.5) * 60)::integer)),
      ROW_NUMBER() OVER (ORDER BY COALESCE(t.weekly_hours, s.weekly_target_hours) DESC)::smallint
    FROM public.subjects s
    LEFT JOIN public.targets t ON t.user_id = p_user_id AND t.subject_id = s.id AND t.is_active
    WHERE s.user_id = p_user_id
    ORDER BY COALESCE(t.weekly_hours, s.weekly_target_hours) DESC
    LIMIT 4
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS inserted_count = ROW_COUNT;
  END IF;

  RETURN inserted_count;
END
$function$;

REVOKE ALL ON FUNCTION public.build_study_plan_for_user(uuid, date) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.refresh_my_study_plan(p_plan_date date DEFAULT (CURRENT_DATE + 1))
RETURNS integer
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$ SELECT public.build_study_plan_for_user(auth.uid(), p_plan_date) $$;
GRANT EXECUTE ON FUNCTION public.refresh_my_study_plan(date) TO authenticated;

CREATE OR REPLACE FUNCTION public.refresh_all_daily_study_plans()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE u record; total integer := 0;
BEGIN
  FOR u IN SELECT DISTINCT user_id FROM public.subjects LOOP
    total := total + public.build_study_plan_for_user(u.user_id, CURRENT_DATE + 1);
  END LOOP;
  RETURN total;
END
$function$;
REVOKE ALL ON FUNCTION public.refresh_all_daily_study_plans() FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.complete_matching_daily_plan()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
BEGIN
  IF OLD.is_running AND NOT NEW.is_running AND NEW.ended_at IS NOT NULL THEN
    UPDATE public.daily_study_plan_items
    SET completed_at = NEW.ended_at, completed_session_id = NEW.id, updated_at = now()
    WHERE id = (
      SELECT p.id FROM public.daily_study_plan_items p
      WHERE p.user_id = NEW.user_id AND p.plan_date = (NEW.ended_at AT TIME ZONE 'UTC')::date
        AND p.completed_at IS NULL
        AND (p.subject_id IS NULL OR p.subject_id = NEW.subject_id)
        AND (p.chapter_name IS NULL OR lower(btrim(p.chapter_name)) = lower(btrim(COALESCE(NEW.topic, ''))))
      ORDER BY p.priority LIMIT 1
    );
  END IF;
  RETURN NEW;
END
$function$;

DROP TRIGGER IF EXISTS complete_daily_plan_from_session ON public.study_sessions;
CREATE TRIGGER complete_daily_plan_from_session
AFTER UPDATE OF is_running, ended_at ON public.study_sessions
FOR EACH ROW EXECUTE FUNCTION public.complete_matching_daily_plan();

-- pg_cron is available on hosted Supabase projects. If the project disallows
-- extension management, enable pg_cron in Dashboard > Database > Extensions,
-- then rerun only this block.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
DO $cron$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'chronodeck-daily-study-plans') THEN
    PERFORM cron.unschedule('chronodeck-daily-study-plans');
  END IF;
  PERFORM cron.schedule(
    'chronodeck-daily-study-plans',
    '10 18 * * *',
    'SELECT public.refresh_all_daily_study_plans();'
  );
END
$cron$;

COMMIT;
