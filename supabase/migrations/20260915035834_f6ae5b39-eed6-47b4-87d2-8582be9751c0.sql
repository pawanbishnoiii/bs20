ALTER TABLE public.user_xp
  ADD COLUMN IF NOT EXISTS best_streak integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_streak_at timestamptz;

CREATE POLICY "Users upload own avatar files"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'data'
  AND (storage.foldername(name))[1] = 'avatars'
  AND split_part((storage.foldername(name))[2], '-', 1) = auth.uid()::text
);

CREATE POLICY "Users read own avatar files"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'data'
  AND (storage.foldername(name))[1] = 'avatars'
  AND split_part((storage.foldername(name))[2], '-', 1) = auth.uid()::text
);

CREATE POLICY "Users update own avatar files"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'data'
  AND (storage.foldername(name))[1] = 'avatars'
  AND split_part((storage.foldername(name))[2], '-', 1) = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'data'
  AND (storage.foldername(name))[1] = 'avatars'
  AND split_part((storage.foldername(name))[2], '-', 1) = auth.uid()::text
);

CREATE POLICY "Users delete own avatar files"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'data'
  AND (storage.foldername(name))[1] = 'avatars'
  AND split_part((storage.foldername(name))[2], '-', 1) = auth.uid()::text
);

CREATE OR REPLACE FUNCTION public.update_study_streak()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  previous_at timestamptz;
  next_streak integer;
BEGIN
  IF NOT (OLD.is_running AND NOT NEW.is_running AND NEW.ended_at IS NOT NULL) THEN
    RETURN NEW;
  END IF;

  INSERT INTO public.user_xp (user_id, total_xp, level, streak, best_streak, last_streak_at)
  VALUES (NEW.user_id, GREATEST(COALESCE(NEW.xp_earned, 0), 1), 1, 1, 1, NEW.ended_at)
  ON CONFLICT (user_id) DO UPDATE
  SET total_xp = public.user_xp.total_xp + GREATEST(COALESCE(NEW.xp_earned, 0), 1),
      level = GREATEST(1, floor((public.user_xp.total_xp + GREATEST(COALESCE(NEW.xp_earned, 0), 1)) / 500.0)::integer + 1),
      streak = CASE
        WHEN public.user_xp.last_streak_at IS NULL THEN GREATEST(public.user_xp.streak, 1)
        WHEN NEW.ended_at - public.user_xp.last_streak_at <= interval '48 hours'
          AND (NEW.ended_at AT TIME ZONE 'UTC')::date > (public.user_xp.last_streak_at AT TIME ZONE 'UTC')::date
          THEN public.user_xp.streak + 1
        WHEN NEW.ended_at - public.user_xp.last_streak_at <= interval '48 hours'
          THEN public.user_xp.streak
        ELSE 1
      END,
      best_streak = GREATEST(
        public.user_xp.best_streak,
        CASE
          WHEN public.user_xp.last_streak_at IS NULL THEN GREATEST(public.user_xp.streak, 1)
          WHEN NEW.ended_at - public.user_xp.last_streak_at <= interval '48 hours'
            AND (NEW.ended_at AT TIME ZONE 'UTC')::date > (public.user_xp.last_streak_at AT TIME ZONE 'UTC')::date
            THEN public.user_xp.streak + 1
          WHEN NEW.ended_at - public.user_xp.last_streak_at <= interval '48 hours'
            THEN public.user_xp.streak
          ELSE 1
        END
      ),
      last_streak_at = GREATEST(COALESCE(public.user_xp.last_streak_at, NEW.ended_at), NEW.ended_at),
      updated_at = now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS update_streak_from_session ON public.study_sessions;
CREATE TRIGGER update_streak_from_session
AFTER UPDATE ON public.study_sessions
FOR EACH ROW EXECUTE FUNCTION public.update_study_streak();

GRANT EXECUTE ON FUNCTION public.update_study_streak() TO service_role;
REVOKE ALL ON FUNCTION public.update_study_streak() FROM PUBLIC, anon, authenticated;