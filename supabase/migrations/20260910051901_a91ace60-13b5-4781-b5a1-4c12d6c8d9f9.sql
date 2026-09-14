REVOKE EXECUTE ON FUNCTION public.user_local_date(uuid) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.log_reading(text, integer) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.undo_reading(text) FROM anon, PUBLIC;
REVOKE EXECUTE ON FUNCTION public.auto_schedule_targets() FROM anon, PUBLIC;
GRANT EXECUTE ON FUNCTION public.user_local_date(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_reading(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.undo_reading(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.auto_schedule_targets() TO authenticated;