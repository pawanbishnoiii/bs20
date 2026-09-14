CREATE OR REPLACE FUNCTION public.user_local_date(_user_id uuid)
RETURNS date
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT (now() AT TIME ZONE COALESCE(NULLIF((SELECT p.timezone FROM public.profiles p WHERE p.id = _user_id), ''), 'Asia/Kolkata'))::date
$$;

CREATE TABLE IF NOT EXISTS public.reading_goals (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  newspaper_daily_minutes integer NOT NULL DEFAULT 15,
  magazine_monthly_minutes integer NOT NULL DEFAULT 45,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.reading_goals TO authenticated;
GRANT ALL ON public.reading_goals TO service_role;

ALTER TABLE public.reading_goals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own reading goals" ON public.reading_goals;
CREATE POLICY "own reading goals" ON public.reading_goals
  FOR ALL TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP TRIGGER IF EXISTS reading_goals_updated_at ON public.reading_goals;
CREATE TRIGGER reading_goals_updated_at
  BEFORE UPDATE ON public.reading_goals
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.log_reading(_kind text, _minutes integer)
RETURNS public.reading_logs
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _row public.reading_logs;
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  IF _kind NOT IN ('newspaper', 'magazine') THEN
    RAISE EXCEPTION 'Unknown reading kind: %', _kind;
  END IF;
  IF _minutes IS NULL OR _minutes < 1 OR _minutes > 600 THEN
    RAISE EXCEPTION 'Minutes must be between 1 and 600';
  END IF;

  INSERT INTO public.reading_logs (user_id, kind, log_date, minutes)
  VALUES (_uid, _kind, public.user_local_date(_uid), _minutes)
  ON CONFLICT (user_id, kind, log_date)
  DO UPDATE SET minutes = public.reading_logs.minutes + EXCLUDED.minutes,
                updated_at = now()
  RETURNING * INTO _row;

  RETURN _row;
END;
$$;

CREATE OR REPLACE FUNCTION public.undo_reading(_kind text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;
  DELETE FROM public.reading_logs
  WHERE user_id = _uid
    AND kind = _kind
    AND log_date = public.user_local_date(_uid);
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS targets_user_subject_key
  ON public.targets (user_id, subject_id)
  WHERE subject_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.auto_schedule_targets()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  _uid uuid := auth.uid();
  _count integer := 0;
  _s record;
  _weekly numeric;
  _daily numeric;
BEGIN
  IF _uid IS NULL THEN
    RAISE EXCEPTION 'Not signed in';
  END IF;

  FOR _s IN
    SELECT s.id, s.name, s.weekly_target_hours
    FROM public.subjects s
    WHERE s.user_id = _uid
  LOOP
    SELECT COALESCE(SUM(ss.duration_minutes), 0) / 2.0 / 60.0
      INTO _weekly
    FROM public.study_sessions ss
    WHERE ss.user_id = _uid
      AND ss.subject_id = _s.id
      AND ss.is_running = false
      AND ss.started_at >= now() - interval '14 days';

    IF _weekly IS NULL OR _weekly < 0.5 THEN
      _weekly := GREATEST(COALESCE(_s.weekly_target_hours, 0), 1);
    END IF;

    _weekly := LEAST(ROUND(_weekly * 2) / 2.0, 60);
    _daily := LEAST(ROUND((_weekly / 6.0) * 2) / 2.0, 12);

    INSERT INTO public.targets (user_id, subject_id, title, daily_hours, weekly_hours, is_active, chapters)
    VALUES (_uid, _s.id, _s.name, _daily, _weekly, true, '[]'::jsonb)
    ON CONFLICT (user_id, subject_id) WHERE subject_id IS NOT NULL
    DO UPDATE SET daily_hours = EXCLUDED.daily_hours,
                  weekly_hours = EXCLUDED.weekly_hours,
                  is_active = true;

    _count := _count + 1;
  END LOOP;

  RETURN _count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.user_local_date(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.log_reading(text, integer) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.undo_reading(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auto_schedule_targets() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_local_date(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reading(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.undo_reading(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_schedule_targets() TO authenticated;