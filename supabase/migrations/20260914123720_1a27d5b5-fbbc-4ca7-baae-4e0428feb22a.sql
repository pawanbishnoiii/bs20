BEGIN;

ALTER TABLE IF EXISTS public.app_settings RENAME TO app_settings_legacy_kv;
ALTER TABLE IF EXISTS public.email_settings RENAME TO email_settings_legacy_kv;
ALTER TABLE IF EXISTS public.motivations RENAME TO motivations_legacy_kv;
ALTER TABLE IF EXISTS public.scheduled_notifications RENAME TO scheduled_notifications_legacy_kv;

CREATE TABLE public.app_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  site_name text NOT NULL DEFAULT 'Chronodeck Study OS',
  tagline text NOT NULL DEFAULT 'Study smarter, every day',
  support_email text,
  banner_text text,
  ai_enabled boolean NOT NULL DEFAULT true,
  manual_log_enabled boolean NOT NULL DEFAULT true,
  landing_enabled boolean NOT NULL DEFAULT true,
  maintenance_note text,
  signup_enabled boolean NOT NULL DEFAULT true,
  google_auth_enabled boolean NOT NULL DEFAULT true,
  one_tap_enabled boolean NOT NULL DEFAULT true,
  email_auth_enabled boolean NOT NULL DEFAULT true,
  onboarding_require_subjects boolean NOT NULL DEFAULT true,
  default_daily_goal_hours numeric NOT NULL DEFAULT 4,
  default_weekly_goal_hours numeric NOT NULL DEFAULT 25,
  announcement_level text NOT NULL DEFAULT 'info',
  accent_color text NOT NULL DEFAULT '#A9C9FF',
  favicon_url text,
  logo_url text,
  push_enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.app_settings TO anon, authenticated;
GRANT INSERT, UPDATE ON public.app_settings TO authenticated;
GRANT ALL ON public.app_settings TO service_role;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_settings_read_all" ON public.app_settings FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "app_settings_admin_write" ON public.app_settings FOR UPDATE TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE POLICY "app_settings_admin_insert" ON public.app_settings FOR INSERT TO authenticated
  WITH CHECK (public.has_role(auth.uid(),'admin'));
INSERT INTO public.app_settings (id) VALUES (true);

CREATE TABLE public.email_settings (
  id boolean PRIMARY KEY DEFAULT true CHECK (id),
  provider text NOT NULL DEFAULT 'lovable' CHECK (provider IN ('lovable','smtp')),
  smtp_host text,
  smtp_port integer,
  smtp_user text,
  smtp_password text,
  from_email text,
  from_name text,
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.email_settings TO authenticated;
GRANT ALL ON public.email_settings TO service_role;
ALTER TABLE public.email_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "email_settings_admin_all" ON public.email_settings FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
INSERT INTO public.email_settings (id) VALUES (true);

CREATE TABLE public.motivations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind text NOT NULL DEFAULT 'quote',
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  author text,
  month smallint CHECK (month IS NULL OR month BETWEEN 1 AND 12),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.motivations TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.motivations TO authenticated;
GRANT ALL ON public.motivations TO service_role;
ALTER TABLE public.motivations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "motivations_read_all" ON public.motivations FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "motivations_admin_write" ON public.motivations FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE TABLE public.scheduled_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  kind text NOT NULL DEFAULT 'info',
  audience text NOT NULL DEFAULT 'all',
  action_path text,
  image_url text,
  send_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','sending','sent','failed','cancelled')),
  error text,
  sent_at timestamptz,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.scheduled_notifications TO authenticated;
GRANT ALL ON public.scheduled_notifications TO service_role;
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "scheduled_notifications_admin_all" ON public.scheduled_notifications FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));
CREATE INDEX scheduled_notifications_due_idx ON public.scheduled_notifications (status, send_at);

CREATE OR REPLACE FUNCTION public.touch_last_seen()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.profiles SET last_seen_at = now(), sign_in_count = COALESCE(sign_in_count,0)
  WHERE id = auth.uid();
$$;
REVOKE ALL ON FUNCTION public.touch_last_seen() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.touch_last_seen() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_overview()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE res jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'total_users', (SELECT count(*) FROM public.profiles),
    'onboarded_users', (SELECT count(*) FROM public.profiles WHERE onboarded),
    'active_today', (SELECT count(*) FROM public.profiles WHERE last_seen_at >= now() - interval '1 day'),
    'active_week', (SELECT count(*) FROM public.profiles WHERE last_seen_at >= now() - interval '7 days'),
    'sessions_today', (SELECT count(*) FROM public.study_sessions WHERE started_at >= date_trunc('day', now())),
    'minutes_today', (SELECT COALESCE(sum(duration_minutes),0) FROM public.study_sessions WHERE started_at >= date_trunc('day', now())),
    'minutes_week', (SELECT COALESCE(sum(duration_minutes),0) FROM public.study_sessions WHERE started_at >= now() - interval '7 days'),
    'total_subjects', (SELECT count(*) FROM public.subjects),
    'events_today', (SELECT count(*) FROM public.app_events WHERE created_at >= date_trunc('day', now()))
  ) INTO res;
  RETURN res;
END $fn$;
REVOKE ALL ON FUNCTION public.admin_overview() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_overview() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_users(_limit integer DEFAULT 100)
RETURNS TABLE (
  id uuid, display_name text, email text, avatar_url text, onboarded boolean,
  last_seen_at timestamptz, created_at timestamptz, total_minutes bigint, session_count bigint
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.display_name, p.email, p.avatar_url, p.onboarded, p.last_seen_at, p.created_at,
         COALESCE(sum(s.duration_minutes),0)::bigint, count(s.id)::bigint
  FROM public.profiles p
  LEFT JOIN public.study_sessions s ON s.user_id = p.id
  GROUP BY p.id
  ORDER BY p.created_at DESC
  LIMIT GREATEST(1, LEAST(_limit, 1000));
END $fn$;
REVOKE ALL ON FUNCTION public.admin_users(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_users(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_push_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE res jsonb;
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT jsonb_build_object(
    'devices', (SELECT count(*) FROM public.device_tokens),
    'subscribers', (SELECT count(DISTINCT user_id) FROM public.device_tokens),
    'total_users', (SELECT count(*) FROM public.profiles),
    'web', (SELECT count(*) FROM public.device_tokens WHERE platform = 'web'),
    'android', (SELECT count(*) FROM public.device_tokens WHERE platform = 'android'),
    'sent_today', (SELECT count(*) FROM public.notifications WHERE created_at >= date_trunc('day', now()))
  ) INTO res;
  RETURN res;
END $fn$;
REVOKE ALL ON FUNCTION public.admin_push_stats() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_push_stats() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_push_subscribers(_limit integer DEFAULT 200)
RETURNS TABLE (
  user_id uuid, display_name text, email text, avatar_url text,
  platforms text, devices bigint, last_seen_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT p.id, p.display_name, p.email, p.avatar_url,
         string_agg(DISTINCT d.platform, ', '), count(d.id)::bigint, max(d.last_seen_at)
  FROM public.device_tokens d
  JOIN public.profiles p ON p.id = d.user_id
  GROUP BY p.id
  ORDER BY max(d.last_seen_at) DESC NULLS LAST
  LIMIT GREATEST(1, LEAST(_limit, 1000));
END $fn$;
REVOKE ALL ON FUNCTION public.admin_push_subscribers(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_push_subscribers(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_notification_history(_limit integer DEFAULT 50)
RETURNS TABLE (
  title text, body text, kind text, image_url text, action_path text,
  audience text, recipients bigint, read_count bigint, sent_at timestamptz
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  RETURN QUERY
  SELECT n.title, n.body, n.kind, n.image_url, n.action_path, n.audience,
         count(*)::bigint, count(*) FILTER (WHERE n.read)::bigint, max(n.created_at)
  FROM public.notifications n
  GROUP BY n.title, n.body, n.kind, n.image_url, n.action_path, n.audience
  ORDER BY max(n.created_at) DESC
  LIMIT GREATEST(1, LEAST(_limit, 500));
END $fn$;
REVOKE ALL ON FUNCTION public.admin_notification_history(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_notification_history(integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_role(_user_id uuid, _role app_role)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
BEGIN
  IF NOT public.has_role(auth.uid(),'admin') THEN RAISE EXCEPTION 'forbidden'; END IF;
  DELETE FROM public.user_roles WHERE user_id = _user_id;
  INSERT INTO public.user_roles (user_id, role) VALUES (_user_id, _role)
  ON CONFLICT DO NOTHING;
END $fn$;
REVOKE ALL ON FUNCTION public.admin_set_role(uuid, app_role) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_role(uuid, app_role) TO authenticated;

CREATE OR REPLACE FUNCTION public.close_stale_sessions()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $fn$
DECLARE n integer;
BEGIN
  UPDATE public.study_sessions s
  SET is_running = false, auto_closed = true, ended_at = now(),
      duration_minutes = GREATEST(0, (EXTRACT(EPOCH FROM (now() - s.started_at))/60)::int
                                     - COALESCE(s.break_minutes,0))
  FROM public.user_settings us
  WHERE us.user_id = s.user_id AND s.is_running
    AND s.started_at < now() - (COALESCE(us.auto_stop_hours, 6) || ' hours')::interval;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END $fn$;
REVOKE ALL ON FUNCTION public.close_stale_sessions() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.close_stale_sessions() TO service_role;

COMMIT;