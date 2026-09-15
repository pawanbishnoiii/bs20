CREATE OR REPLACE FUNCTION public.ensure_my_subject_targets()
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE _uid uuid := auth.uid(); _count integer;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  INSERT INTO public.subject_targets (
    user_id, subject_id, daily_minutes, weekly_minutes, monthly_minutes,
    daily_topics, weekly_topics, monthly_topics,
    daily_chapters, weekly_chapters, monthly_chapters,
    daily_questions, weekly_questions, monthly_questions, auto_created
  )
  SELECT _uid, s.id,
    GREATEST(20, LEAST(240, round(GREATEST(s.weekly_target_hours, 1) * 60 / 6.0)::integer)),
    GREATEST(60, round(GREATEST(s.weekly_target_hours, 1) * 60)::integer),
    GREATEST(240, round(GREATEST(s.weekly_target_hours, 1) * 60 * 4.345)::integer),
    1, GREATEST(3, LEAST(14, jsonb_array_length(COALESCE(s.chapters, '[]'::jsonb)))),
    GREATEST(12, LEAST(60, jsonb_array_length(COALESCE(s.chapters, '[]'::jsonb)) * 4)),
    0, CASE WHEN jsonb_array_length(COALESCE(s.chapters, '[]'::jsonb)) > 0 THEN 1 ELSE 0 END,
    GREATEST(1, LEAST(12, jsonb_array_length(COALESCE(s.chapters, '[]'::jsonb)))),
    10, 60, 240, true
  FROM public.subjects s
  WHERE s.user_id = _uid
  ON CONFLICT (user_id, subject_id) DO NOTHING;
  GET DIAGNOSTICS _count = ROW_COUNT;
  RETURN _count;
END;
$$;

CREATE OR REPLACE FUNCTION public.schedule_my_daily_plan(p_plan_date date DEFAULT CURRENT_DATE)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid(); _item record; _window record; _cursor time; _finish time;
  _count integer := 0; _dow integer := extract(dow from p_plan_date)::integer;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  FOR _item IN
    SELECT p.id, p.target_minutes FROM public.daily_study_plan_items p
    WHERE p.user_id = _uid AND p.plan_date = p_plan_date
      AND p.completed_at IS NULL AND p.scheduled_start IS NULL
    ORDER BY p.priority, p.created_at
  LOOP
    FOR _window IN
      SELECT b.start_time, b.end_time FROM public.timetable_blocks b
      WHERE b.user_id = _uid AND b.day_of_week = _dow ORDER BY b.start_time
    LOOP
      SELECT GREATEST(_window.start_time, COALESCE(MAX(p.scheduled_end), _window.start_time)) INTO _cursor
      FROM public.daily_study_plan_items p
      WHERE p.user_id = _uid AND p.plan_date = p_plan_date
        AND p.scheduled_start >= _window.start_time AND p.scheduled_end <= _window.end_time;
      _finish := _cursor + make_interval(mins => _item.target_minutes);
      IF _finish <= _window.end_time THEN
        UPDATE public.daily_study_plan_items
        SET scheduled_start = _cursor, scheduled_end = _finish, updated_at = now()
        WHERE id = _item.id AND user_id = _uid;
        _count := _count + 1;
        EXIT;
      END IF;
    END LOOP;
  END LOOP;
  RETURN _count;
END;
$$;

CREATE OR REPLACE FUNCTION public.build_study_plan_for_user(p_user_id uuid, p_plan_date date DEFAULT (CURRENT_DATE + 1))
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE revision_count integer := 0; reading_count integer := 0; fallback_count integer := 0;
BEGIN
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'user_id is required'; END IF;
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date
    AND source = 'automatic' AND completed_at IS NULL AND pinned = false;
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, subject_name, chapter_id, chapter_name, session_kind,
     target_minutes, priority, review_stage, next_review_at)
  SELECT p_user_id, p_plan_date, c.subject_id, s.name, c.chapter_id, c.chapter_name, 'revision',
    GREATEST(20, LEAST(60, round(COALESCE(st.daily_minutes, s.weekly_target_hours * 60 / 6.0, 30))::integer)),
    row_number() OVER (ORDER BY c.next_review_at, c.review_stage DESC)::smallint,
    c.review_stage, c.next_review_at
  FROM public.chapter_learning_state c JOIN public.subjects s ON s.id = c.subject_id AND s.user_id = p_user_id
  LEFT JOIN public.subject_targets st ON st.user_id = p_user_id AND st.subject_id = s.id
  WHERE c.user_id = p_user_id AND c.next_review_at < (p_plan_date + interval '1 day')
  ORDER BY c.next_review_at, c.review_stage DESC LIMIT 6
  ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
  GET DIAGNOSTICS revision_count = ROW_COUNT;
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority)
  SELECT p_user_id, p_plan_date, x.subject_id, x.subject_name, x.chapter_name, 'reading',
    GREATEST(30, LEAST(120, round(COALESCE(x.daily_minutes, x.weekly_target_hours * 60 / 6.0, 30))::integer)),
    (revision_count + row_number() OVER (ORDER BY x.weekly_target_hours DESC))::smallint
  FROM (
    SELECT DISTINCT ON (s.id) s.id AS subject_id, s.name AS subject_name, chapter.value AS chapter_name,
      s.weekly_target_hours, st.daily_minutes
    FROM public.subjects s
    CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(s.chapters, '[]'::jsonb)) WITH ORDINALITY AS chapter(value, ordinality)
    LEFT JOIN public.chapter_learning_state c ON c.user_id = p_user_id AND c.subject_id = s.id
      AND lower(btrim(c.chapter_name)) = lower(btrim(chapter.value))
    LEFT JOIN public.subject_targets st ON st.user_id = p_user_id AND st.subject_id = s.id
    WHERE s.user_id = p_user_id AND c.id IS NULL ORDER BY s.id, chapter.ordinality
  ) x ORDER BY x.weekly_target_hours DESC LIMIT GREATEST(0, 8 - revision_count)
  ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
  GET DIAGNOSTICS reading_count = ROW_COUNT;
  IF revision_count + reading_count = 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority)
    SELECT p_user_id, p_plan_date, s.id, s.name, NULL, 'reading',
      GREATEST(25, LEAST(180, round(COALESCE(st.daily_minutes, t.daily_hours * 60, s.weekly_target_hours * 60 / 7.0, 30))::integer)),
      row_number() OVER (ORDER BY COALESCE(st.weekly_minutes, t.weekly_hours * 60, s.weekly_target_hours * 60) DESC)::smallint
    FROM public.subjects s LEFT JOIN public.targets t ON t.user_id = p_user_id AND t.subject_id = s.id AND t.is_active
    LEFT JOIN public.subject_targets st ON st.user_id = p_user_id AND st.subject_id = s.id
    WHERE s.user_id = p_user_id
    ORDER BY COALESCE(st.weekly_minutes, t.weekly_hours * 60, s.weekly_target_hours * 60) DESC LIMIT 4
    ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
    GET DIAGNOSTICS fallback_count = ROW_COUNT;
  END IF;
  RETURN revision_count + reading_count + fallback_count;
END;
$$;
REVOKE ALL ON FUNCTION public.build_study_plan_for_user(uuid, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.build_study_plan_for_user(uuid, date) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.refresh_my_study_plan(p_plan_date date DEFAULT (CURRENT_DATE + 1))
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE _uid uuid := auth.uid(); _result integer;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  PERFORM public.ensure_my_subject_targets();
  _result := public.build_study_plan_for_user(_uid, p_plan_date);
  PERFORM public.schedule_my_daily_plan(p_plan_date);
  RETURN _result;
END;
$$;