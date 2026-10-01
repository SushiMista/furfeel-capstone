-- =========================================================================
-- Backfill Script: Seed Initial Biometrics for All Existing Dogs
-- (EXCLUDES any dog paired with the physical ESP32 device 'FURFEEL-DEV-0002')
-- =========================================================================

do $$
declare
  r record;
  v_device_id uuid;
  v_device_code text;
  v_reading_id uuid;
  v_captured_at timestamptz;
  v_hr int;
  v_rr int;
  v_motion numeric(4,3);
  v_posture posture_type;
  v_score numeric(4,1);
  i int;
begin
  -- Loop through all dogs that do NOT use the physical ESP32 'FURFEEL-DEV-0002'
  for r in
    select 
      d.id as dog_id,
      d.name as dog_name,
      dev.id as existing_device_id,
      dev.device_code as existing_device_code
    from public.dogs d
    left join public.devices dev on dev.dog_id = d.id
    where coalesce(dev.device_code, '') <> 'FURFEEL-DEV-0002'
  loop
    -- 1. Ensure the dog has an assigned device collar
    if r.existing_device_id is not null then
      v_device_id := r.existing_device_id;
      v_device_code := r.existing_device_code;
    else
      -- Generate clean device code for unassigned dog (e.g. COLLAR-DOGNAME)
      v_device_code := 'COLLAR-' || upper(regexp_replace(r.dog_name, '[^a-zA-Z0-9]', '', 'g'));
      
      -- If device code already exists, append a short random hex
      if exists (select 1 from public.devices where device_code = v_device_code) then
        v_device_code := v_device_code || '-' || upper(substring(gen_random_uuid()::text from 1 for 4));
      end if;

      insert into public.devices (dog_id, device_code, status, firmware_version, battery_percent, last_seen_at)
      values (r.dog_id, v_device_code, 'active', '0.1.0', 95, now())
      returning id into v_device_id;
    end if;

    -- 2. Only insert biometrics if the dog doesn't have any recent telemetry readings
    if not exists (
      select 1 from public.telemetry_readings where dog_id = r.dog_id
    ) then
      -- Generate 6 time-series data points across the last 30 minutes
      for i in 1..6 loop
        v_captured_at := now() - ((6 - i) * interval '5 minutes');
        
        -- Realistic canine baseline biometrics
        v_hr := 82 + floor(random() * 10 - 4)::int; -- 78 - 88 bpm
        v_rr := 20 + floor(random() * 6 - 3)::int;  -- 17 - 23 bpm
        v_motion := round((0.110 + (random() * 0.140))::numeric, 3);
        
        if v_motion < 0.170 then
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
          v_device_id,
          r.dog_id,
          v_captured_at,
          v_captured_at + interval '1 second',
          v_hr,
          v_rr,
          v_motion,
          v_posture,
          24.2 + round((random() * 1.2 - 0.6)::numeric, 1),
          51.5 + round((random() * 3.0 - 1.5)::numeric, 1),
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
          r.dog_id,
          v_reading_id,
          'calm'::stress_level,
          v_score,
          0.950,
          '["Normal resting heart rate within baseline", "Low motion activity", "Resting posture detected"]'::jsonb,
          'rule-v1',
          v_captured_at
        );
      end loop;

      -- Update collar status to active and 95% battery
      update public.devices
      set status = 'active',
          battery_percent = 95,
          last_seen_at = now()
      where id = v_device_id;
    end if;
  end loop;
end;
$$;
