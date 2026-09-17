REVOKE EXECUTE ON FUNCTION public.advance_chapter_learning_state() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.close_stale_sessions() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.complete_matching_daily_plan() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.refresh_all_daily_study_plans() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.update_study_streak() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.open_class_notes_revision() FROM anon, authenticated, public;
REVOKE EXECUTE ON FUNCTION public.streak_from_reading() FROM anon, authenticated, public;