ALTER TABLE public.subjects ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.targets ADD COLUMN IF NOT EXISTS chapters jsonb NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE public.study_sessions ADD COLUMN IF NOT EXISTS chapter text;

CREATE TABLE IF NOT EXISTS public.reading_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('newspaper','magazine')),
  log_date date NOT NULL DEFAULT (now()::date),
  minutes integer NOT NULL DEFAULT 15,
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, kind, log_date)
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.reading_logs TO authenticated;
GRANT ALL ON public.reading_logs TO service_role;

ALTER TABLE public.reading_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own reading logs" ON public.reading_logs
  FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TRIGGER reading_logs_updated_at BEFORE UPDATE ON public.reading_logs
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();