DO $cron$
BEGIN
  BEGIN
    EXECUTE 'CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron unavailable; planner installed without cron';
  END;

  IF to_regprocedure('cron.schedule(text,text,text)') IS NOT NULL THEN
    PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'chronodeck-daily-study-plans';
    PERFORM cron.schedule(
      'chronodeck-daily-study-plans',
      '10 18 * * *',
      'SELECT public.refresh_all_daily_study_plans();'
    );
  END IF;
END
$cron$;