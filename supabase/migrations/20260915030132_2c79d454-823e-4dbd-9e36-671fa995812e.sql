
ALTER TABLE public.chapter_learning_state
  ADD COLUMN IF NOT EXISTS reading_sessions integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS revision_sessions integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS class_sessions integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS practice_sessions integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS first_pass_completed_at timestamptz;

CREATE OR REPLACE VIEW public.chapter_time_stats
WITH (security_invoker = true) AS
SELECT
  c.user_id,
  c.subject_id,
  c.chapter_id,
  c.chapter_name,
  c.review_stage,
  c.next_review_at,
  c.last_studied_at,
  c.first_pass_completed_at,
  c.reading_minutes,
  c.revision_minutes,
  c.class_minutes,
  c.practice_minutes,
  (c.reading_minutes + c.revision_minutes + c.class_minutes + c.practice_minutes) AS total_minutes,
  c.reading_sessions,
  c.revision_sessions,
  round(c.reading_minutes::numeric / GREATEST(c.reading_sessions, 1), 1) AS avg_reading_minutes,
  round(c.revision_minutes::numeric / GREATEST(c.revision_sessions, 1), 1) AS avg_revision_minutes,
  round((c.reading_minutes + c.revision_minutes + c.class_minutes + c.practice_minutes)::numeric
        / GREATEST(c.reading_sessions + c.revision_sessions + c.class_sessions + c.practice_sessions, 1), 1)
    AS avg_session_minutes
FROM public.chapter_learning_state c;

GRANT SELECT ON public.chapter_time_stats TO authenticated;
GRANT ALL ON public.chapter_time_stats TO service_role;

CREATE OR REPLACE FUNCTION public.chapter_pace(_user_id uuid DEFAULT auth.uid())
RETURNS TABLE(chapters_tracked integer, chapters_completed integer,
              avg_chapter_minutes numeric, avg_reading_minutes numeric, avg_revision_minutes numeric)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    count(*)::integer,
    count(*) FILTER (WHERE first_pass_completed_at IS NOT NULL)::integer,
    round(COALESCE(avg(reading_minutes + revision_minutes + class_minutes + practice_minutes)
      FILTER (WHERE first_pass_completed_at IS NOT NULL), 0), 1),
    round(COALESCE(avg(NULLIF(reading_minutes, 0)), 0), 1),
    round(COALESCE(avg(NULLIF(revision_minutes, 0) / GREATEST(revision_sessions, 1)), 0), 1)
  FROM public.chapter_learning_state
  WHERE user_id = COALESCE(_user_id, auth.uid())
    AND (auth.uid() IS NULL OR auth.uid() = COALESCE(_user_id, auth.uid()));
$$;

GRANT EXECUTE ON FUNCTION public.chapter_pace(uuid) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.advance_chapter_learning_state()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  _chapter text := NULLIF(btrim(COALESCE(NEW.chapter, NEW.topic, '')), '');
  _mins integer := GREATEST(COALESCE(NEW.duration_minutes,0), 0);
  _stage smallint;
BEGIN
  IF NOT (OLD.is_running AND NOT NEW.is_running AND NEW.ended_at IS NOT NULL) THEN
    RETURN NEW;
  END IF;
  IF NEW.subject_id IS NULL OR _chapter IS NULL OR _mins = 0 THEN
    RETURN NEW;
  END IF;

  SELECT c.review_stage INTO _stage
  FROM public.chapter_learning_state c
  WHERE c.user_id = NEW.user_id AND c.subject_id = NEW.subject_id
    AND lower(btrim(c.chapter_name)) = lower(_chapter);

  IF _stage IS NULL THEN
    INSERT INTO public.chapter_learning_state
      (user_id, subject_id, chapter_name, review_stage, next_review_at, last_studied_at,
       reading_minutes, revision_minutes, class_minutes, practice_minutes,
       reading_sessions, revision_sessions, class_sessions, practice_sessions,
       first_pass_completed_at)
    VALUES (NEW.user_id, NEW.subject_id, _chapter, 0,
            now() + (public.review_interval_days(0::smallint) || ' days')::interval, NEW.ended_at,
            CASE WHEN NEW.kind = 'reading' THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind = 'revision' THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind IN ('class','live') THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind IN ('practice','test') THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind = 'reading' THEN 1 ELSE 0 END,
            CASE WHEN NEW.kind = 'revision' THEN 1 ELSE 0 END,
            CASE WHEN NEW.kind IN ('class','live') THEN 1 ELSE 0 END,
            CASE WHEN NEW.kind IN ('practice','test') THEN 1 ELSE 0 END,
            CASE WHEN NEW.kind = 'reading' THEN NEW.ended_at ELSE NULL END);
  ELSE
    UPDATE public.chapter_learning_state c
    SET reading_minutes = c.reading_minutes + CASE WHEN NEW.kind = 'reading' THEN _mins ELSE 0 END,
        revision_minutes = c.revision_minutes + CASE WHEN NEW.kind = 'revision' THEN _mins ELSE 0 END,
        class_minutes = c.class_minutes + CASE WHEN NEW.kind IN ('class','live') THEN _mins ELSE 0 END,
        practice_minutes = c.practice_minutes + CASE WHEN NEW.kind IN ('practice','test') THEN _mins ELSE 0 END,
        reading_sessions = c.reading_sessions + CASE WHEN NEW.kind = 'reading' THEN 1 ELSE 0 END,
        revision_sessions = c.revision_sessions + CASE WHEN NEW.kind = 'revision' THEN 1 ELSE 0 END,
        class_sessions = c.class_sessions + CASE WHEN NEW.kind IN ('class','live') THEN 1 ELSE 0 END,
        practice_sessions = c.practice_sessions + CASE WHEN NEW.kind IN ('practice','test') THEN 1 ELSE 0 END,
        first_pass_completed_at = COALESCE(c.first_pass_completed_at,
          CASE WHEN NEW.kind IN ('reading','revision') THEN NEW.ended_at ELSE NULL END),
        review_stage = CASE WHEN NEW.kind = 'revision' THEN LEAST(c.review_stage + 1, 4)::smallint ELSE c.review_stage END,
        next_review_at = now() + (public.review_interval_days(
            (CASE WHEN NEW.kind = 'revision' THEN LEAST(c.review_stage + 1, 4) ELSE c.review_stage END)::smallint
          ) || ' days')::interval,
        last_studied_at = NEW.ended_at,
        updated_at = now()
    WHERE c.user_id = NEW.user_id AND c.subject_id = NEW.subject_id
      AND lower(btrim(c.chapter_name)) = lower(_chapter);
  END IF;

  RETURN NEW;
END $function$;

-- Backfill sitting counts from recorded sessions so pace is meaningful from day one.
WITH counted AS (
  SELECT ss.user_id, ss.subject_id, lower(btrim(COALESCE(ss.chapter, ss.topic, ''))) AS chap,
    count(*) FILTER (WHERE ss.kind = 'reading') AS r,
    count(*) FILTER (WHERE ss.kind = 'revision') AS v,
    count(*) FILTER (WHERE ss.kind IN ('class','live')) AS c,
    count(*) FILTER (WHERE ss.kind IN ('practice','test')) AS p,
    min(ss.ended_at) AS first_done
  FROM public.study_sessions ss
  WHERE ss.ended_at IS NOT NULL AND ss.subject_id IS NOT NULL
    AND NULLIF(btrim(COALESCE(ss.chapter, ss.topic, '')), '') IS NOT NULL
  GROUP BY 1,2,3
)
UPDATE public.chapter_learning_state cls
SET reading_sessions = GREATEST(counted.r, CASE WHEN cls.reading_minutes > 0 THEN 1 ELSE 0 END),
    revision_sessions = GREATEST(counted.v, CASE WHEN cls.revision_minutes > 0 THEN 1 ELSE 0 END),
    class_sessions = counted.c,
    practice_sessions = counted.p,
    first_pass_completed_at = COALESCE(cls.first_pass_completed_at, counted.first_done)
FROM counted
WHERE counted.user_id = cls.user_id AND counted.subject_id = cls.subject_id
  AND counted.chap = lower(btrim(cls.chapter_name));

CREATE OR REPLACE FUNCTION public.build_study_plan_for_user(p_user_id uuid, p_plan_date date DEFAULT (CURRENT_DATE + 1))
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
  revision_count integer := 0; reading_count integer := 0; fallback_count integer := 0;
  pace_read numeric; pace_revise numeric;
BEGIN
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'user_id is required'; END IF;
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN RAISE EXCEPTION 'forbidden'; END IF;

  -- Learner's own measured pace drives the minimum minutes per plan item.
  SELECT round(COALESCE(avg(NULLIF(reading_minutes, 0) / GREATEST(reading_sessions, 1)), 0), 0),
         round(COALESCE(avg(NULLIF(revision_minutes, 0) / GREATEST(revision_sessions, 1)), 0), 0)
    INTO pace_read, pace_revise
  FROM public.chapter_learning_state WHERE user_id = p_user_id;
  pace_read := GREATEST(20, LEAST(150, COALESCE(NULLIF(pace_read, 0), 45)));
  pace_revise := GREATEST(10, LEAST(60, COALESCE(NULLIF(pace_revise, 0), round(pace_read * 0.4))));

  DELETE FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date
    AND source = 'automatic' AND completed_at IS NULL AND pinned = false;

  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, subject_name, chapter_id, chapter_name, session_kind,
     target_minutes, priority, review_stage, next_review_at)
  SELECT p_user_id, p_plan_date, c.subject_id, s.name, c.chapter_id, c.chapter_name, 'revision',
    GREATEST(10, LEAST(90, round(COALESCE(
      NULLIF(c.revision_minutes, 0)::numeric / GREATEST(c.revision_sessions, 1),
      pace_revise))::integer)),
    row_number() OVER (ORDER BY c.next_review_at, c.review_stage DESC)::smallint,
    c.review_stage, c.next_review_at
  FROM public.chapter_learning_state c JOIN public.subjects s ON s.id = c.subject_id AND s.user_id = p_user_id
  WHERE c.user_id = p_user_id AND c.next_review_at < (p_plan_date + interval '1 day')
  ORDER BY c.next_review_at, c.review_stage DESC LIMIT 6
  ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
  GET DIAGNOSTICS revision_count = ROW_COUNT;

  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, x.subject_id, x.subject_name, x.chapter_name, 'reading',
    GREATEST(20, LEAST(150, round(pace_read)::integer)),
    (revision_count + row_number() OVER (ORDER BY x.weekly_target_hours DESC))::smallint
  FROM (
    SELECT DISTINCT ON (s.id) s.id AS subject_id, s.name AS subject_name, chapter.value AS chapter_name,
      s.weekly_target_hours
    FROM public.subjects s
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(s.chapters, '[]'::jsonb)) WITH ORDINALITY AS chapter(value, ordinality)
    LEFT JOIN public.chapter_learning_state c ON c.user_id = p_user_id AND c.subject_id = s.id
      AND lower(btrim(c.chapter_name)) = lower(btrim(chapter.value))
    WHERE s.user_id = p_user_id AND c.id IS NULL ORDER BY s.id, chapter.ordinality
  ) x ORDER BY x.weekly_target_hours DESC LIMIT GREATEST(0, 8 - revision_count)
  ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
  GET DIAGNOSTICS reading_count = ROW_COUNT;

  IF revision_count + reading_count = 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority)
    SELECT p_user_id, p_plan_date, s.id, s.name, NULL, 'reading',
      GREATEST(20, LEAST(180, round(COALESCE(st.daily_minutes, pace_read))::integer)),
      row_number() OVER (ORDER BY COALESCE(st.weekly_minutes, s.weekly_target_hours * 60) DESC)::smallint
    FROM public.subjects s
    LEFT JOIN public.subject_targets st ON st.user_id = p_user_id AND st.subject_id = s.id
    WHERE s.user_id = p_user_id
    ORDER BY COALESCE(st.weekly_minutes, s.weekly_target_hours * 60) DESC LIMIT 4
    ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
    GET DIAGNOSTICS fallback_count = ROW_COUNT;
  END IF;

  RETURN revision_count + reading_count + fallback_count;
END;
$function$;
