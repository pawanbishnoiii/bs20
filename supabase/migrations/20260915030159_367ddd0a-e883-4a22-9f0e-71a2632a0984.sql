
DROP FUNCTION IF EXISTS public.chapter_pace(uuid);

CREATE OR REPLACE FUNCTION public.chapter_pace()
RETURNS TABLE(chapters_tracked integer, chapters_completed integer,
              avg_chapter_minutes numeric, avg_reading_minutes numeric, avg_revision_minutes numeric)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
  SELECT
    count(*)::integer,
    count(*) FILTER (WHERE first_pass_completed_at IS NOT NULL)::integer,
    round(COALESCE(avg(reading_minutes + revision_minutes + class_minutes + practice_minutes)
      FILTER (WHERE first_pass_completed_at IS NOT NULL), 0), 1),
    round(COALESCE(avg(NULLIF(reading_minutes, 0) / GREATEST(reading_sessions, 1)), 0), 1),
    round(COALESCE(avg(NULLIF(revision_minutes, 0) / GREATEST(revision_sessions, 1)), 0), 1)
  FROM public.chapter_learning_state;
$$;

REVOKE ALL ON FUNCTION public.chapter_pace() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.chapter_pace() TO authenticated, service_role;
