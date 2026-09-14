ALTER TABLE public.app_settings
  ADD COLUMN IF NOT EXISTS avatar_upload_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS android_min_version text,
  ADD COLUMN IF NOT EXISTS android_latest_version text,
  ADD COLUMN IF NOT EXISTS android_update_url text,
  ADD COLUMN IF NOT EXISTS android_force_update boolean NOT NULL DEFAULT false;