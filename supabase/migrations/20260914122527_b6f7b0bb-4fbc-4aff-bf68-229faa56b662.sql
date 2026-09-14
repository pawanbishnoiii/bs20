-- ============ helpers ============
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('admin','moderator','user');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION public.set_chronodeck_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

-- ============ profiles ============
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  first_name text,
  last_name text,
  display_name text,
  bio text,
  phone text,
  gender text,
  age integer,
  timezone text NOT NULL DEFAULT 'UTC',
  avatar_url text,
  onboarded boolean NOT NULL DEFAULT false,
  onboarded_at timestamptz,
  last_seen_at timestamptz,
  sign_in_count integer NOT NULL DEFAULT 0,
  avg_study_hours numeric,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS profiles_own ON public.profiles;
CREATE POLICY profiles_own ON public.profiles FOR ALL TO authenticated
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- ============ roles ============
CREATE TABLE IF NOT EXISTS public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.app_role NOT NULL DEFAULT 'user',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);
GRANT SELECT ON public.user_roles TO authenticated;
GRANT ALL ON public.user_roles TO service_role;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_roles_read_own ON public.user_roles;
CREATE POLICY user_roles_read_own ON public.user_roles FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role public.app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

DROP POLICY IF EXISTS user_roles_admin_all ON public.user_roles;
CREATE POLICY user_roles_admin_all ON public.user_roles FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

DROP POLICY IF EXISTS profiles_admin_read ON public.profiles;
CREATE POLICY profiles_admin_read ON public.profiles FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(),'admin'));

-- ============ subjects ============
CREATE TABLE IF NOT EXISTS public.subjects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  color text NOT NULL DEFAULT '#A9C9FF',
  chapters jsonb NOT NULL DEFAULT '[]'::jsonb,
  weekly_target_hours numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS subjects_user_idx ON public.subjects(user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.subjects TO authenticated;
GRANT ALL ON public.subjects TO service_role;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS subjects_own ON public.subjects;
CREATE POLICY subjects_own ON public.subjects FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ targets ============
CREATE TABLE IF NOT EXISTS public.targets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  title text NOT NULL,
  chapters jsonb NOT NULL DEFAULT '[]'::jsonb,
  deadline date,
  is_active boolean NOT NULL DEFAULT true,
  daily_hours numeric NOT NULL DEFAULT 0,
  weekly_hours numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS targets_user_idx ON public.targets(user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.targets TO authenticated;
GRANT ALL ON public.targets TO service_role;
ALTER TABLE public.targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS targets_own ON public.targets;
CREATE POLICY targets_own ON public.targets FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ study_sessions ============
CREATE TABLE IF NOT EXISTS public.study_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  subject_name text,
  chapter text,
  topic text,
  category text,
  kind text NOT NULL DEFAULT 'reading',
  notes text,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  planned_end_at timestamptz,
  is_running boolean NOT NULL DEFAULT true,
  auto_closed boolean NOT NULL DEFAULT false,
  break_type text,
  break_started_at timestamptz,
  break_minutes integer NOT NULL DEFAULT 0,
  total_break_seconds integer NOT NULL DEFAULT 0,
  duration_minutes integer,
  duration_seconds integer,
  xp_earned integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS study_sessions_user_started_idx ON public.study_sessions(user_id, started_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS study_sessions_one_running_idx
  ON public.study_sessions(user_id) WHERE is_running;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.study_sessions TO authenticated;
GRANT ALL ON public.study_sessions TO service_role;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS study_sessions_own ON public.study_sessions;
CREATE POLICY study_sessions_own ON public.study_sessions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ legacy sessions (compat) ============
CREATE TABLE IF NOT EXISTS public.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  kind text NOT NULL DEFAULT 'reading',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_minutes integer,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.sessions TO authenticated;
GRANT ALL ON public.sessions TO service_role;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sessions_own ON public.sessions;
CREATE POLICY sessions_own ON public.sessions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ session_breaks ============
CREATE TABLE IF NOT EXISTS public.session_breaks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.study_sessions(id) ON DELETE CASCADE,
  kind text NOT NULL DEFAULT 'free',
  note text,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  duration_minutes integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS session_breaks_session_idx ON public.session_breaks(session_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.session_breaks TO authenticated;
GRANT ALL ON public.session_breaks TO service_role;
ALTER TABLE public.session_breaks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS session_breaks_own ON public.session_breaks;
CREATE POLICY session_breaks_own ON public.session_breaks FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ timetable_blocks ============
CREATE TABLE IF NOT EXISTS public.timetable_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  title text NOT NULL,
  kind text NOT NULL DEFAULT 'study',
  day_of_week integer NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
  start_time time NOT NULL,
  end_time time NOT NULL,
  week_parity text NOT NULL DEFAULT 'all',
  location text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS timetable_user_day_idx ON public.timetable_blocks(user_id, day_of_week);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.timetable_blocks TO authenticated;
GRANT ALL ON public.timetable_blocks TO service_role;
ALTER TABLE public.timetable_blocks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS timetable_own ON public.timetable_blocks;
CREATE POLICY timetable_own ON public.timetable_blocks FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ user_settings ============
CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  daily_goal_hours numeric NOT NULL DEFAULT 4,
  weekly_goal_hours numeric NOT NULL DEFAULT 25,
  auto_stop_hours numeric NOT NULL DEFAULT 6,
  week_starts_monday boolean NOT NULL DEFAULT true,
  ai_tone text NOT NULL DEFAULT 'friendly',
  ai_autopilot boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_settings TO authenticated;
GRANT ALL ON public.user_settings TO service_role;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_settings_own ON public.user_settings;
CREATE POLICY user_settings_own ON public.user_settings FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP TRIGGER IF EXISTS user_settings_updated_at ON public.user_settings;
CREATE TRIGGER user_settings_updated_at BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION public.set_chronodeck_updated_at();

-- ============ user_xp ============
CREATE TABLE IF NOT EXISTS public.user_xp (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  total_xp integer NOT NULL DEFAULT 0,
  level integer NOT NULL DEFAULT 1,
  streak integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_xp TO authenticated;
GRANT ALL ON public.user_xp TO service_role;
ALTER TABLE public.user_xp ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_xp_own ON public.user_xp;
CREATE POLICY user_xp_own ON public.user_xp FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ notifications ============
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  body text,
  kind text NOT NULL DEFAULT 'info',
  audience text NOT NULL DEFAULT 'all',
  action_path text,
  image_url text,
  read boolean NOT NULL DEFAULT false,
  push_sent boolean NOT NULL DEFAULT false,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS notifications_user_idx ON public.notifications(user_id, created_at DESC);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT ALL ON public.notifications TO service_role;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notifications_own ON public.notifications;
CREATE POLICY notifications_own ON public.notifications FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS notifications_admin ON public.notifications;
CREATE POLICY notifications_admin ON public.notifications FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- ============ scheduled_notifications ============
CREATE TABLE IF NOT EXISTS public.scheduled_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text,
  kind text NOT NULL DEFAULT 'info',
  audience text NOT NULL DEFAULT 'all',
  action_path text,
  image_url text,
  scheduled_for timestamptz NOT NULL,
  sent_at timestamptz,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.scheduled_notifications TO authenticated;
GRANT ALL ON public.scheduled_notifications TO service_role;
ALTER TABLE public.scheduled_notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS scheduled_notifications_admin ON public.scheduled_notifications;
CREATE POLICY scheduled_notifications_admin ON public.scheduled_notifications FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- ============ device_tokens ============
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token text NOT NULL UNIQUE,
  platform text NOT NULL DEFAULT 'web',
  device_label text,
  last_seen_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_tokens TO authenticated;
GRANT ALL ON public.device_tokens TO service_role;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS device_tokens_own ON public.device_tokens;
CREATE POLICY device_tokens_own ON public.device_tokens FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ app_events ============
CREATE TABLE IF NOT EXISTS public.app_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  event text NOT NULL,
  path text,
  platform text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS app_events_user_idx ON public.app_events(user_id, created_at DESC);
GRANT SELECT, INSERT ON public.app_events TO authenticated;
GRANT ALL ON public.app_events TO service_role;
ALTER TABLE public.app_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_events_insert_own ON public.app_events;
CREATE POLICY app_events_insert_own ON public.app_events FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS app_events_select_own ON public.app_events;
CREATE POLICY app_events_select_own ON public.app_events FOR SELECT TO authenticated
  USING (auth.uid() = user_id OR public.has_role(auth.uid(),'admin'));

-- ============ ai_messages ============
CREATE TABLE IF NOT EXISTS public.ai_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'user',
  content text NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ai_messages_user_idx ON public.ai_messages(user_id, created_at);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ai_messages TO authenticated;
GRANT ALL ON public.ai_messages TO service_role;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ai_messages_own ON public.ai_messages;
CREATE POLICY ai_messages_own ON public.ai_messages FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ============ admin / app tables ============
CREATE TABLE IF NOT EXISTS public.app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.app_settings TO anon, authenticated;
GRANT ALL ON public.app_settings TO service_role;
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS app_settings_read ON public.app_settings;
CREATE POLICY app_settings_read ON public.app_settings FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS app_settings_admin ON public.app_settings;
CREATE POLICY app_settings_admin ON public.app_settings FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE TABLE IF NOT EXISTS public.avatar_presets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  image_url text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.avatar_presets TO authenticated;
GRANT ALL ON public.avatar_presets TO service_role;
ALTER TABLE public.avatar_presets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS avatar_presets_read ON public.avatar_presets;
CREATE POLICY avatar_presets_read ON public.avatar_presets FOR SELECT TO authenticated USING (is_active);
DROP POLICY IF EXISTS avatar_presets_admin ON public.avatar_presets;
CREATE POLICY avatar_presets_admin ON public.avatar_presets FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE TABLE IF NOT EXISTS public.email_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL DEFAULT 'resend',
  from_email text,
  from_name text,
  enabled boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT ALL ON public.email_settings TO service_role;
GRANT SELECT ON public.email_settings TO authenticated;
ALTER TABLE public.email_settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS email_settings_admin ON public.email_settings;
CREATE POLICY email_settings_admin ON public.email_settings FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE TABLE IF NOT EXISTS public.jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  status text NOT NULL DEFAULT 'pending',
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  run_at timestamptz NOT NULL DEFAULT now(),
  started_at timestamptz,
  finished_at timestamptz,
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.jobs TO authenticated;
GRANT ALL ON public.jobs TO service_role;
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS jobs_admin ON public.jobs;
CREATE POLICY jobs_admin ON public.jobs FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE TABLE IF NOT EXISTS public.motivations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  text text NOT NULL,
  author text,
  language text NOT NULL DEFAULT 'en',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT ON public.motivations TO authenticated;
GRANT ALL ON public.motivations TO service_role;
ALTER TABLE public.motivations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS motivations_read ON public.motivations;
CREATE POLICY motivations_read ON public.motivations FOR SELECT TO authenticated USING (is_active);
DROP POLICY IF EXISTS motivations_admin ON public.motivations;
CREATE POLICY motivations_admin ON public.motivations FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin')) WITH CHECK (public.has_role(auth.uid(),'admin'));

-- ============ new user bootstrap ============
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email,'@',1)))
  ON CONFLICT (id) DO NOTHING;
  INSERT INTO public.user_settings (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_xp (user_id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
  INSERT INTO public.user_roles (user_id, role) VALUES (NEW.id, 'user') ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();