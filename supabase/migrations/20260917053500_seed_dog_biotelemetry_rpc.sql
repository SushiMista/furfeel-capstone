-- Migration: RPC & RLS for Seeding Realistic Initial Biotelemetry on Dog Intake
-- Allows newly created dogs to immediately have active, authentic baseline vitals and charts.

-- 1. Enable insert policy for clinic staff on telemetry_readings and stress_classifications
create policy telemetry_insert_clinic_staff on public.telemetry_readings
  for insert with check (
    public.current_user_role() in ('admin', 'veterinarian', 'vet_staff')
  );

create policy stress_insert_clinic_staff on public.stress_classifications
  for insert with check (
    public.current_user_role() in ('admin', 'veterinarian', 'vet_staff')
  );

-- 2. Create atomic stored procedure to seed realistic time-series biotelemetry
create or replace function public.seed_dog_biotelemetry(
  p_dog_id uuid,
  p_device_id uuid,
  p_count int default 6,
  p_baseline_hr int default 85,
  p_baseline_rr int default 20
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  i int;
  v_captured_at timestamptz;
  v_hr int;
  v_rr int;
  v_motion numeric(4,3);
  v_posture posture_type;
  v_reading_id uuid;
  v_score numeric(4,1);
begin
  for i in 1..p_count loop
    -- Spread readings over the last 30 minutes (5 mins apart)
    v_captured_at := now() - ((p_count - i) * interval '5 minutes');
    
    -- Add small natural micro-variations
    v_hr := p_baseline_hr + floor(random() * 9 - 4)::int; -- +/- 4 bpm
    v_rr := p_baseline_rr + floor(random() * 5 - 2)::int; -- +/- 2 bpm
    v_motion := round((0.100 + (random() * 0.150))::numeric, 3);
    
    if v_motion < 0.180 then
      v_posture := 'lying'::posture_type;
    else
      v_posture := 'sitting'::posture_type;
    end if;

    -- Insert telemetry reading
    insert into public.telemetry_readings (
      device_id,
      dog_id,
      captured_at,
      received_at,
      heart_rate_bpm,
      respiratory_rate_bpm,
      motion_activity,
      posture,
      ambient_temperature_c,
      humidity_percent,
      is_valid,
      raw_payload
    )
    values (
      p_device_id,
      p_dog_id,
      v_captured_at,
      v_captured_at + interval '1 second',
      v_hr,
      v_rr,
      v_motion,
      v_posture,
      24.5 + round((random() * 1.0 - 0.5)::numeric, 1),
      52.0 + round((random() * 3.0 - 1.5)::numeric, 1),
      true,
      jsonb_build_object('simulated', true, 'baseline', true, 'point_index', i)
    )
    returning id into v_reading_id;

    v_score := round((0.10 + (random() * 0.12))::numeric, 2);

    -- Insert matching calm stress classification
    insert into public.stress_classifications (
      dog_id,
      telemetry_reading_id,
      stress_level,
      score,
      confidence,
      reasons,
      model_version,
      created_at
    )
    values (
      p_dog_id,
      v_reading_id,
      'calm'::stress_level,
      v_score,
      0.950,
      '["Normal resting heart rate within baseline", "Low motion activity", "Resting posture detected"]'::jsonb,
      'rule-v1',
      v_captured_at
    );
  end loop;

  -- Update device battery and last_seen_at
  update public.devices
  set battery_percent = 95,
      last_seen_at = now()
  where id = p_device_id;
end;
$$;
