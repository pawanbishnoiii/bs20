CREATE OR REPLACE FUNCTION public.review_interval_days(_stage smallint)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE GREATEST(COALESCE(_stage,0),0)
    WHEN 0 THEN 1 WHEN 1 THEN 3 WHEN 2 THEN 7 WHEN 3 THEN 15 ELSE 30 END
$$;

CREATE OR REPLACE FUNCTION public.advance_chapter_learning_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
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
       reading_minutes, revision_minutes, class_minutes, practice_minutes)
    VALUES (NEW.user_id, NEW.subject_id, _chapter, 0,
            now() + (public.review_interval_days(0::smallint) || ' days')::interval, NEW.ended_at,
            CASE WHEN NEW.kind = 'reading' THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind = 'revision' THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind IN ('class','live') THEN _mins ELSE 0 END,
            CASE WHEN NEW.kind IN ('practice','test') THEN _mins ELSE 0 END);
  ELSE
    UPDATE public.chapter_learning_state c
    SET reading_minutes = c.reading_minutes + CASE WHEN NEW.kind = 'reading' THEN _mins ELSE 0 END,
        revision_minutes = c.revision_minutes + CASE WHEN NEW.kind = 'revision' THEN _mins ELSE 0 END,
        class_minutes = c.class_minutes + CASE WHEN NEW.kind IN ('class','live') THEN _mins ELSE 0 END,
        practice_minutes = c.practice_minutes + CASE WHEN NEW.kind IN ('practice','test') THEN _mins ELSE 0 END,
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
END $$;

DROP TRIGGER IF EXISTS advance_chapter_state_from_session ON public.study_sessions;
CREATE TRIGGER advance_chapter_state_from_session
AFTER UPDATE ON public.study_sessions
FOR EACH ROW EXECUTE FUNCTION public.advance_chapter_learning_state();

CREATE OR REPLACE FUNCTION public.build_study_plan_for_user(p_user_id uuid, p_plan_date date DEFAULT (CURRENT_DATE + 1))
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  revision_count integer := 0;
  reading_count integer := 0;
  fallback_count integer := 0;
BEGIN
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'user_id is required'; END IF;

  DELETE FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date
    AND source = 'automatic' AND completed_at IS NULL AND pinned = false;

  -- 1) Due revisions first (1/3/7/15/30 day spacing)
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, c.subject_id, c.chapter_name, 'revision',
    GREATEST(20, LEAST(60, ROUND(COALESCE(s.weekly_target_hours, 3) * 60 / 10.0)::integer)),
    ROW_NUMBER() OVER (ORDER BY c.next_review_at, c.review_stage DESC)::smallint
  FROM public.chapter_learning_state c
  JOIN public.subjects s ON s.id = c.subject_id AND s.user_id = p_user_id
  WHERE c.user_id = p_user_id AND c.next_review_at < (p_plan_date + interval '1 day')
  ORDER BY c.next_review_at, c.review_stage DESC
  LIMIT 4;
  GET DIAGNOSTICS revision_count = ROW_COUNT;

  -- 2) Reading of chapters not yet started, one per subject, weighted by target
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, x.subject_id, x.chapter_name, 'reading',
    GREATEST(30, LEAST(120, ROUND(COALESCE(x.weekly_target_hours, 3) * 60 / 6.0)::integer)),
    (revision_count + ROW_NUMBER() OVER (ORDER BY x.weekly_target_hours DESC))::smallint
  FROM (
    SELECT DISTINCT ON (s.id) s.id AS subject_id, chapter.value AS chapter_name, s.weekly_target_hours
    FROM public.subjects s
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(s.chapters, '[]'::jsonb))
      WITH ORDINALITY AS chapter(value, ordinality)
    LEFT JOIN public.chapter_learning_state c
      ON c.user_id = p_user_id AND c.subject_id = s.id
     AND lower(btrim(c.chapter_name)) = lower(btrim(chapter.value))
    WHERE s.user_id = p_user_id AND c.id IS NULL
    ORDER BY s.id, chapter.ordinality
  ) x
  ORDER BY x.weekly_target_hours DESC
  LIMIT GREATEST(0, 7 - revision_count);
  GET DIAGNOSTICS reading_count = ROW_COUNT;

  -- 3) No chapters at all: plan plain subject blocks so the day is never empty
  IF revision_count + reading_count = 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, chapter_name, session_kind, target_minutes, priority)
    SELECT p_user_id, p_plan_date, s.id, NULL, 'reading',
      GREATEST(25, LEAST(180, ROUND(COALESCE(t.daily_hours, s.weekly_target_hours / 7.0, 0.5) * 60)::integer)),
      ROW_NUMBER() OVER (ORDER BY COALESCE(t.weekly_hours, s.weekly_target_hours) DESC)::smallint
    FROM public.subjects s
    LEFT JOIN public.targets t ON t.user_id = p_user_id AND t.subject_id = s.id AND t.is_active
    WHERE s.user_id = p_user_id
    ORDER BY COALESCE(t.weekly_hours, s.weekly_target_hours) DESC
    LIMIT 4;
    GET DIAGNOSTICS fallback_count = ROW_COUNT;
  END IF;

  RETURN revision_count + reading_count + fallback_count;
END $$;