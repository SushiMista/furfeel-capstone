-- Add granular posture types (walking, running, trembling) matching ML model output
-- and IoT harness telemetry classifications.
ALTER TYPE public.posture_type ADD VALUE IF NOT EXISTS 'walking';
ALTER TYPE public.posture_type ADD VALUE IF NOT EXISTS 'running';
ALTER TYPE public.posture_type ADD VALUE IF NOT EXISTS 'trembling';
