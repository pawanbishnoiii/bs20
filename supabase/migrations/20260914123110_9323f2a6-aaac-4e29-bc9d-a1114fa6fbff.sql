REVOKE ALL ON FUNCTION public.build_study_plan_for_user(uuid, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_all_daily_study_plans() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_matching_daily_plan() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.build_study_plan_for_user(uuid, date) TO service_role;
GRANT EXECUTE ON FUNCTION public.refresh_all_daily_study_plans() TO service_role;