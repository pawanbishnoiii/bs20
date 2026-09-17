-- 1. Plan item lifecycle -------------------------------------------------
ALTER TABLE public.daily_study_plan_items
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS skipped_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz,
  ADD COLUMN IF NOT EXISTS rank_score numeric NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS class_id uuid REFERENCES public.online_classes(id) ON DELETE SET NULL;

-- 2. Online class lifecycle ----------------------------------------------
ALTER TABLE public.online_classes
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'scheduled',
  ADD COLUMN IF NOT EXISTS completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS chapter_name text,
  ADD COLUMN IF NOT EXISTS notes_taken boolean NOT NULL DEFAULT false;

-- 3. Class-notes revision state ------------------------------------------
CREATE TABLE IF NOT EXISTS public.class_note_revision_state (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  class_id uuid NOT NULL REFERENCES public.online_classes(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE,
  chapter_id uuid REFERENCES public.chapters(id) ON DELETE SET NULL,
  chapter_name text,
  title text NOT NULL,
  review_stage smallint NOT NULL DEFAULT 0,
  revisions_done integer NOT NULL DEFAULT 0,
  target_revisions integer NOT NULL DEFAULT 6,
  next_review_at timestamptz NOT NULL DEFAULT now(),
  last_revised_at timestamptz,
  total_minutes integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, class_id)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.class_note_revision_state TO authenticated;
GRANT ALL ON public.class_note_revision_state TO service_role;
ALTER TABLE public.class_note_revision_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own class note revisions" ON public.class_note_revision_state
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE TRIGGER set_class_note_revision_state_updated_at BEFORE UPDATE
  ON public.class_note_revision_state FOR EACH ROW EXECUTE FUNCTION public.set_chronodeck_updated_at();

-- when a class is marked completed, open a notes-revision track
CREATE OR REPLACE FUNCTION public.open_class_notes_revision()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.status = 'completed' AND (TG_OP = 'INSERT' OR COALESCE(OLD.status,'') <> 'completed') THEN
    INSERT INTO public.class_note_revision_state
      (user_id, class_id, subject_id, chapter_id, chapter_name, title, next_review_at, target_revisions)
    VALUES (NEW.user_id, NEW.id, NEW.subject_id, NEW.chapter_id, NEW.chapter_name, NEW.title,
            now() + interval '1 day', 6)
    ON CONFLICT (user_id, class_id) DO NOTHING;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS open_class_notes_revision_trg ON public.online_classes;
CREATE TRIGGER open_class_notes_revision_trg AFTER INSERT OR UPDATE ON public.online_classes
  FOR EACH ROW EXECUTE FUNCTION public.open_class_notes_revision();

-- 4. Longer spaced-repetition ladder (4-8 passes per topic) ---------------
CREATE OR REPLACE FUNCTION public.review_interval_days(_stage smallint)
RETURNS integer LANGUAGE sql IMMUTABLE SET search_path = public AS $$
  SELECT CASE GREATEST(COALESCE(_stage,0),0)
    WHEN 0 THEN 1 WHEN 1 THEN 3 WHEN 2 THEN 7 WHEN 3 THEN 15
    WHEN 4 THEN 30 WHEN 5 THEN 45 WHEN 6 THEN 60 ELSE 90 END
$$;

CREATE OR REPLACE FUNCTION public.advance_chapter_learning_state()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  _chapter text := NULLIF(btrim(COALESCE(NEW.chapter, NEW.topic, '')), '');
  _mins integer := GREATEST(COALESCE(NEW.duration_minutes,0), 0);
  _stage smallint;
BEGIN
  IF NOT (OLD.is_running AND NOT NEW.is_running AND NEW.ended_at IS NOT NULL) THEN RETURN NEW; END IF;
  IF NEW.subject_id IS NULL OR _chapter IS NULL OR _mins = 0 THEN RETURN NEW; END IF;

  SELECT c.review_stage INTO _stage FROM public.chapter_learning_state c
  WHERE c.user_id = NEW.user_id AND c.subject_id = NEW.subject_id
    AND lower(btrim(c.chapter_name)) = lower(_chapter);

  IF _stage IS NULL THEN
    INSERT INTO public.chapter_learning_state
      (user_id, subject_id, chapter_name, review_stage, next_review_at, last_studied_at,
       reading_minutes, revision_minutes, class_minutes, practice_minutes,
       reading_sessions, revision_sessions, class_sessions, practice_sessions, first_pass_completed_at)
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
        review_stage = CASE WHEN NEW.kind = 'revision' THEN LEAST(c.review_stage + 1, 7)::smallint ELSE c.review_stage END,
        next_review_at = now() + (public.review_interval_days(
            (CASE WHEN NEW.kind = 'revision' THEN LEAST(c.review_stage + 1, 7) ELSE c.review_stage END)::smallint
          ) || ' days')::interval,
        last_studied_at = NEW.ended_at,
        updated_at = now()
    WHERE c.user_id = NEW.user_id AND c.subject_id = NEW.subject_id
      AND lower(btrim(c.chapter_name)) = lower(_chapter);
  END IF;
  RETURN NEW;
END $$;

-- 5. Plan builder: ranked, capped at 8 active, includes class-notes revision
CREATE OR REPLACE FUNCTION public.build_study_plan_for_user(p_user_id uuid, p_plan_date date DEFAULT (CURRENT_DATE + 1))
RETURNS integer LANGUAGE plpgsql SET search_path = public AS $$
DECLARE
  added integer := 0; n integer; active_count integer; slots integer;
  pace_read numeric; pace_revise numeric;
BEGIN
  IF p_user_id IS NULL THEN RAISE EXCEPTION 'user_id is required'; END IF;
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id THEN RAISE EXCEPTION 'forbidden'; END IF;

  SELECT round(COALESCE(avg(NULLIF(reading_minutes,0)/GREATEST(reading_sessions,1)),0),0),
         round(COALESCE(avg(NULLIF(revision_minutes,0)/GREATEST(revision_sessions,1)),0),0)
    INTO pace_read, pace_revise
  FROM public.chapter_learning_state WHERE user_id = p_user_id;
  pace_read := GREATEST(20, LEAST(150, COALESCE(NULLIF(pace_read,0), 45)));
  pace_revise := GREATEST(10, LEAST(60, COALESCE(NULLIF(pace_revise,0), round(pace_read*0.4))));

  -- drop untouched auto items so the board can be rebuilt
  DELETE FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date AND source = 'automatic'
    AND completed_at IS NULL AND pinned = false AND status = 'pending';

  SELECT count(*) INTO active_count FROM public.daily_study_plan_items
  WHERE user_id = p_user_id AND plan_date = p_plan_date AND status = 'pending' AND completed_at IS NULL;
  slots := GREATEST(0, 12 - active_count);
  IF slots = 0 THEN RETURN 0; END IF;

  -- a) overdue chapter revisions (highest rank)
  INSERT INTO public.daily_study_plan_items
    (user_id, plan_date, subject_id, subject_name, chapter_id, chapter_name, session_kind,
     target_minutes, priority, review_stage, next_review_at, rank_score)
  SELECT p_user_id, p_plan_date, c.subject_id, s.name, c.chapter_id, c.chapter_name, 'revision',
    GREATEST(10, LEAST(90, round(COALESCE(NULLIF(c.revision_minutes,0)::numeric/GREATEST(c.revision_sessions,1), pace_revise))::integer)),
    row_number() OVER (ORDER BY c.next_review_at, c.review_stage DESC)::smallint,
    c.review_stage, c.next_review_at,
    1000 + LEAST(500, GREATEST(0, EXTRACT(EPOCH FROM (now() - c.next_review_at))/3600)::numeric)
  FROM public.chapter_learning_state c
  JOIN public.subjects s ON s.id = c.subject_id AND s.user_id = p_user_id
  WHERE c.user_id = p_user_id AND c.next_review_at < (p_plan_date + interval '1 day')
  ORDER BY c.next_review_at, c.review_stage DESC
  LIMIT slots
  ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT; added := added + n; slots := slots - n;

  -- b) class-notes revisions
  IF slots > 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, subject_name, chapter_id, chapter_name, session_kind,
       target_minutes, priority, review_stage, next_review_at, rank_score, class_id)
    SELECT p_user_id, p_plan_date, r.subject_id, s.name, r.chapter_id,
      COALESCE(r.chapter_name, r.title), 'notes_revision',
      GREATEST(10, LEAST(45, round(pace_revise*0.8)::integer)),
      (added + row_number() OVER (ORDER BY r.next_review_at))::smallint,
      r.review_stage, r.next_review_at,
      900 + LEAST(400, GREATEST(0, EXTRACT(EPOCH FROM (now() - r.next_review_at))/3600)::numeric),
      r.class_id
    FROM public.class_note_revision_state r
    LEFT JOIN public.subjects s ON s.id = r.subject_id
    WHERE r.user_id = p_user_id AND r.next_review_at < (p_plan_date + interval '1 day')
      AND r.revisions_done < r.target_revisions
    ORDER BY r.next_review_at
    LIMIT slots
    ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; added := added + n; slots := slots - n;
  END IF;

  -- c) fresh chapters from the syllabus
  IF slots > 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority, rank_score)
    SELECT p_user_id, p_plan_date, x.subject_id, x.subject_name, x.chapter_name, 'reading',
      GREATEST(20, LEAST(150, round(pace_read)::integer)),
      (added + row_number() OVER (ORDER BY x.weekly_target_hours DESC))::smallint,
      500 + LEAST(200, x.weekly_target_hours * 10)
    FROM (
      SELECT DISTINCT ON (s.id) s.id AS subject_id, s.name AS subject_name, chapter.value AS chapter_name, s.weekly_target_hours
      FROM public.subjects s
      CROSS JOIN LATERAL jsonb_array_elements_text(COALESCE(s.chapters,'[]'::jsonb)) WITH ORDINALITY AS chapter(value, ordinality)
      LEFT JOIN public.chapter_learning_state c ON c.user_id = p_user_id AND c.subject_id = s.id
        AND lower(btrim(c.chapter_name)) = lower(btrim(chapter.value))
      WHERE s.user_id = p_user_id AND c.id IS NULL ORDER BY s.id, chapter.ordinality
    ) x ORDER BY x.weekly_target_hours DESC LIMIT slots
    ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; added := added + n; slots := slots - n;
  END IF;

  -- d) never leave the board empty
  IF added = 0 AND slots > 0 THEN
    INSERT INTO public.daily_study_plan_items
      (user_id, plan_date, subject_id, subject_name, chapter_name, session_kind, target_minutes, priority, rank_score)
    SELECT p_user_id, p_plan_date, s.id, s.name, NULL, 'reading',
      GREATEST(20, LEAST(180, round(COALESCE(st.daily_minutes, pace_read))::integer)),
      row_number() OVER (ORDER BY COALESCE(st.weekly_minutes, s.weekly_target_hours*60) DESC)::smallint,
      300
    FROM public.subjects s
    LEFT JOIN public.subject_targets st ON st.user_id = p_user_id AND st.subject_id = s.id
    WHERE s.user_id = p_user_id
    ORDER BY COALESCE(st.weekly_minutes, s.weekly_target_hours*60) DESC LIMIT LEAST(slots, 4)
    ON CONFLICT (user_id, plan_date, subject_id, chapter_name, session_kind) DO NOTHING;
    GET DIAGNOSTICS n = ROW_COUNT; added := added + n;
  END IF;

  RETURN added;
END $$;

-- 6. Skip / cancel a plan item, then top the board back up ----------------
CREATE OR REPLACE FUNCTION public.set_plan_item_status(_item_id uuid, _status text)
RETURNS integer LANGUAGE plpgsql SET search_path = public AS $$
DECLARE _uid uuid := auth.uid(); _date date;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF _status NOT IN ('pending','skipped','cancelled') THEN RAISE EXCEPTION 'Unknown status %', _status; END IF;

  UPDATE public.daily_study_plan_items
  SET status = _status,
      skipped_at = CASE WHEN _status = 'skipped' THEN now() ELSE NULL END,
      cancelled_at = CASE WHEN _status = 'cancelled' THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = _item_id AND user_id = _uid
  RETURNING plan_date INTO _date;

  IF _date IS NULL THEN RAISE EXCEPTION 'Plan item not found'; END IF;
  IF _status = 'pending' THEN RETURN 0; END IF;
  RETURN public.build_study_plan_for_user(_uid, _date);
END $$;

-- 7. Reading: timer based, many sittings a day, counts towards streak -----
ALTER TABLE public.reading_logs ADD COLUMN IF NOT EXISTS sittings integer NOT NULL DEFAULT 1;

CREATE OR REPLACE FUNCTION public.log_reading(_kind text, _minutes integer)
RETURNS public.reading_logs LANGUAGE plpgsql SET search_path = public AS $$
DECLARE _uid uuid := auth.uid(); _row public.reading_logs;
BEGIN
  IF _uid IS NULL THEN RAISE EXCEPTION 'Not signed in'; END IF;
  IF _kind NOT IN ('newspaper','magazine') THEN RAISE EXCEPTION 'Unknown reading kind: %', _kind; END IF;
  IF _minutes IS NULL OR _minutes < 1 OR _minutes > 600 THEN RAISE EXCEPTION 'Minutes must be between 1 and 600'; END IF;

  INSERT INTO public.reading_logs (user_id, kind, log_date, minutes, sittings)
  VALUES (_uid, _kind, public.user_local_date(_uid), _minutes, 1)
  ON CONFLICT (user_id, kind, log_date)
  DO UPDATE SET minutes = public.reading_logs.minutes + EXCLUDED.minutes,
                sittings = public.reading_logs.sittings + 1,
                updated_at = now()
  RETURNING * INTO _row;
  RETURN _row;
END $$;

-- reading keeps the streak alive too (48h window, same rule as sessions)
CREATE OR REPLACE FUNCTION public.streak_from_reading()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE _at timestamptz := now();
BEGIN
  INSERT INTO public.user_xp (user_id, total_xp, level, streak, best_streak, last_streak_at)
  VALUES (NEW.user_id, 5, 1, 1, 1, _at)
  ON CONFLICT (user_id) DO UPDATE
  SET total_xp = public.user_xp.total_xp + 5,
      streak = CASE
        WHEN public.user_xp.last_streak_at IS NULL THEN GREATEST(public.user_xp.streak,1)
        WHEN _at - public.user_xp.last_streak_at <= interval '48 hours'
             AND (_at AT TIME ZONE 'UTC')::date > (public.user_xp.last_streak_at AT TIME ZONE 'UTC')::date
          THEN public.user_xp.streak + 1
        WHEN _at - public.user_xp.last_streak_at <= interval '48 hours' THEN public.user_xp.streak
        ELSE 1 END,
      best_streak = GREATEST(public.user_xp.best_streak, public.user_xp.streak),
      last_streak_at = GREATEST(COALESCE(public.user_xp.last_streak_at, _at), _at),
      updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS streak_from_reading_trg ON public.reading_logs;
CREATE TRIGGER streak_from_reading_trg AFTER INSERT OR UPDATE ON public.reading_logs
  FOR EACH ROW EXECUTE FUNCTION public.streak_from_reading();

-- 8. Admin: full export of any user's history ----------------------------
CREATE OR REPLACE FUNCTION public.admin_export_user(_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path = public AS $$
DECLARE res jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'exported_at', now(),
    'user_id', _user_id,
    'profile', (SELECT to_jsonb(p) FROM public.profiles p WHERE p.id = _user_id),
    'settings', (SELECT to_jsonb(u) FROM public.user_settings u WHERE u.user_id = _user_id),
    'xp', (SELECT to_jsonb(x) FROM public.user_xp x WHERE x.user_id = _user_id),
    'roles', (SELECT COALESCE(jsonb_agg(to_jsonb(r)),'[]'::jsonb) FROM public.user_roles r WHERE r.user_id = _user_id),
    'subjects', (SELECT COALESCE(jsonb_agg(to_jsonb(s)),'[]'::jsonb) FROM public.subjects s WHERE s.user_id = _user_id),
    'chapters', (SELECT COALESCE(jsonb_agg(to_jsonb(c)),'[]'::jsonb) FROM public.chapters c WHERE c.user_id = _user_id),
    'chapter_learning_state', (SELECT COALESCE(jsonb_agg(to_jsonb(c)),'[]'::jsonb) FROM public.chapter_learning_state c WHERE c.user_id = _user_id),
    'study_sessions', (SELECT COALESCE(jsonb_agg(to_jsonb(s)),'[]'::jsonb) FROM public.study_sessions s WHERE s.user_id = _user_id),
    'plan_items', (SELECT COALESCE(jsonb_agg(to_jsonb(d)),'[]'::jsonb) FROM public.daily_study_plan_items d WHERE d.user_id = _user_id),
    'targets', (SELECT COALESCE(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM public.targets t WHERE t.user_id = _user_id),
    'subject_targets', (SELECT COALESCE(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM public.subject_targets t WHERE t.user_id = _user_id),
    'timetable_blocks', (SELECT COALESCE(jsonb_agg(to_jsonb(t)),'[]'::jsonb) FROM public.timetable_blocks t WHERE t.user_id = _user_id),
    'reading_logs', (SELECT COALESCE(jsonb_agg(to_jsonb(r)),'[]'::jsonb) FROM public.reading_logs r WHERE r.user_id = _user_id),
    'online_classes', (SELECT COALESCE(jsonb_agg(to_jsonb(o)),'[]'::jsonb) FROM public.online_classes o WHERE o.user_id = _user_id),
    'class_note_revisions', (SELECT COALESCE(jsonb_agg(to_jsonb(c)),'[]'::jsonb) FROM public.class_note_revision_state c WHERE c.user_id = _user_id)
  ) INTO res;
  RETURN res;
END $$;

-- Admin: rich per-user preview
CREATE OR REPLACE FUNCTION public.admin_user_detail(_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path = public AS $$
DECLARE res jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'profile', (SELECT to_jsonb(p) FROM public.profiles p WHERE p.id = _user_id),
    'xp', (SELECT to_jsonb(x) FROM public.user_xp x WHERE x.user_id = _user_id),
    'total_minutes', (SELECT COALESCE(sum(duration_minutes),0) FROM public.study_sessions WHERE user_id = _user_id),
    'session_count', (SELECT count(*) FROM public.study_sessions WHERE user_id = _user_id),
    'subject_count', (SELECT count(*) FROM public.subjects WHERE user_id = _user_id),
    'reading_minutes', (SELECT COALESCE(sum(minutes),0) FROM public.reading_logs WHERE user_id = _user_id),
    'last_seen_at', (SELECT last_seen_at FROM public.profiles WHERE id = _user_id),
    'recent_sessions', (SELECT COALESCE(jsonb_agg(to_jsonb(s) ORDER BY s.started_at DESC),'[]'::jsonb)
                        FROM (SELECT * FROM public.study_sessions WHERE user_id = _user_id ORDER BY started_at DESC LIMIT 25) s),
    'subjects', (SELECT COALESCE(jsonb_agg(to_jsonb(s)),'[]'::jsonb) FROM public.subjects s WHERE s.user_id = _user_id)
  ) INTO res;
  RETURN res;
END $$;

-- Admin: import a previously exported history back into a user account
CREATE OR REPLACE FUNCTION public.admin_import_user(_user_id uuid, _payload jsonb)
RETURNS integer LANGUAGE plpgsql SET search_path = public AS $$
DECLARE n integer := 0;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.subjects (id, user_id, name, color, chapters, weekly_target_hours)
  SELECT COALESCE((e->>'id')::uuid, gen_random_uuid()), _user_id, e->>'name',
         COALESCE(e->>'color','#7C6CF6'), COALESCE(e->'chapters','[]'::jsonb),
         COALESCE((e->>'weekly_target_hours')::numeric, 3)
  FROM jsonb_array_elements(COALESCE(_payload->'subjects','[]'::jsonb)) e
  ON CONFLICT (id) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;

  INSERT INTO public.study_sessions
    (id, user_id, subject_id, subject_name, chapter, topic, kind, notes, started_at, ended_at,
     is_running, duration_minutes, xp_earned)
  SELECT COALESCE((e->>'id')::uuid, gen_random_uuid()), _user_id, (e->>'subject_id')::uuid,
         e->>'subject_name', e->>'chapter', e->>'topic', COALESCE(e->>'kind','reading'), e->>'notes',
         COALESCE((e->>'started_at')::timestamptz, now()), (e->>'ended_at')::timestamptz,
         false, COALESCE((e->>'duration_minutes')::integer, 0), COALESCE((e->>'xp_earned')::integer, 0)
  FROM jsonb_array_elements(COALESCE(_payload->'study_sessions','[]'::jsonb)) e
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.reading_logs (id, user_id, kind, log_date, minutes, note)
  SELECT COALESCE((e->>'id')::uuid, gen_random_uuid()), _user_id, e->>'kind',
         (e->>'log_date')::date, COALESCE((e->>'minutes')::integer,0), e->>'note'
  FROM jsonb_array_elements(COALESCE(_payload->'reading_logs','[]'::jsonb)) e
  ON CONFLICT DO NOTHING;

  RETURN n;
END $$;