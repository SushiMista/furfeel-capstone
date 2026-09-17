-- =========================================================================
-- Migration: Reassign FURFEEL-DEV-0002 to Joshua Valderama
-- and Transfer Seed Biotelemetry Placeholder to Maxine Mendiola
-- =========================================================================

-- 1. Update seed_dog_biotelemetry RPC to guard physical ESP32 hardware
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
  v_device_code text;
  i int;
  v_captured_at timestamptz;
  v_hr int;
  v_rr int;
  v_motion numeric(4,3);
  v_posture posture_type;
  v_reading_id uuid;
  v_score numeric(4,1);
begin
  select device_code into v_device_code from public.devices where id = p_device_id;

  -- Do NOT seed simulated biotelemetry on the real physical ESP32 device
  if v_device_code = 'FURFEEL-DEV-0002' then
    return;
  end if;

  for i in 1..p_count loop
    v_captured_at := now() - ((p_count - i) * interval '5 minutes');
    
    v_hr := p_baseline_hr + floor(random() * 9 - 4)::int;
    v_rr := p_baseline_rr + floor(random() * 5 - 2)::int;
    v_motion := round((0.100 + (random() * 0.150))::numeric, 3);
    
    if v_motion < 0.180 then
      v_posture := 'lying'::posture_type;
    else
      v_posture := 'sitting'::posture_type;
    end if;

    insert into public.telemetry_readings (
      device_id, dog_id, captured_at, received_at, heart_rate_bpm, respiratory_rate_bpm,
      motion_activity, posture, ambient_temperature_c, humidity_percent, is_valid, raw_payload
    )
    values (
      p_device_id, p_dog_id, v_captured_at, v_captured_at + interval '1 second',
      v_hr, v_rr, v_motion, v_posture,
      24.5 + round((random() * 1.0 - 0.5)::numeric, 1),
      52.0 + round((random() * 3.0 - 1.5)::numeric, 1),
      true,
      jsonb_build_object('simulated', true, 'baseline', true, 'point_index', i)
    )
    returning id into v_reading_id;

    v_score := round((0.10 + (random() * 0.12))::numeric, 2);

    insert into public.stress_classifications (
      dog_id, telemetry_reading_id, stress_level, score, confidence, reasons, model_version, created_at
    )
    values (
      p_dog_id, v_reading_id, 'calm'::stress_level, v_score, 0.950,
      '["Normal resting heart rate within baseline", "Low motion activity", "Resting posture detected"]'::jsonb,
      'rule-v1', v_captured_at
    );
  end loop;

  update public.devices set battery_percent = 95, last_seen_at = now() where id = p_device_id;
end;
$$;

-- 2. Execute Dog & Device Reassignment & Data Migration
do $$
declare
  v_joshua_dog_id uuid;
  v_maxine_dog_id uuid;
  v_esp32_device_id uuid;
  v_dummy_device_id uuid;
  v_reading_id uuid;
  v_captured_at timestamptz;
  v_hr int;
  v_rr int;
  v_motion numeric(4,3);
  v_posture posture_type;
  v_score numeric(4,1);
  i int;
begin
  -- Locate target dogs
  select id into v_joshua_dog_id from public.dogs where lower(name) like '%joshua%valderama%' or lower(name) like '%joshua%vaderama%' limit 1;
  select id into v_maxine_dog_id from public.dogs where lower(name) like '%maxine%mendiola%' limit 1;

  -- Locate target devices
  select id into v_esp32_device_id from public.devices where device_code = 'FURFEEL-DEV-0002' limit 1;
  select id into v_dummy_device_id from public.devices where dog_id = v_maxine_dog_id or device_code = 'DEVICE20262' limit 1;

  -- Create dummy collar DEVICE20262 if not exists
  if v_dummy_device_id is null then
    insert into public.devices (dog_id, device_code, status, firmware_version, battery_percent, last_seen_at)
    values (v_maxine_dog_id, 'DEVICE20262', 'active', '0.1.0', 95, now())
    returning id into v_dummy_device_id;
  end if;

  -- Bind FURFEEL-DEV-0002 to Joshua Valderama
  if v_joshua_dog_id is not null and v_esp32_device_id is not null then
    update public.devices set dog_id = null where dog_id = v_joshua_dog_id and id <> v_esp32_device_id;
    update public.devices set dog_id = v_joshua_dog_id where id = v_esp32_device_id;
  end if;

  -- Bind DEVICE20262 to Maxine Mendiola
  if v_maxine_dog_id is not null and v_dummy_device_id is not null then
    update public.devices set dog_id = v_maxine_dog_id, status = 'active', battery_percent = 95, last_seen_at = now() where id = v_dummy_device_id;
  end if;

  -- Clear simulated seed telemetry & stress classifications from Joshua Valderama
  if v_joshua_dog_id is not null then
    delete from public.stress_classifications
    where dog_id = v_joshua_dog_id
      and telemetry_reading_id in (
        select id from public.telemetry_readings
        where dog_id = v_joshua_dog_id
          and (raw_payload->>'simulated' = 'true' or raw_payload->>'baseline' = 'true')
      );

    delete from public.telemetry_readings
    where dog_id = v_joshua_dog_id
      and (raw_payload->>'simulated' = 'true' or raw_payload->>'baseline' = 'true');
  end if;

  -- Seed biotelemetry placeholder for Maxine Mendiola
  if v_maxine_dog_id is not null and v_dummy_device_id is not null then
    delete from public.stress_classifications where dog_id = v_maxine_dog_id;
    delete from public.telemetry_readings where dog_id = v_maxine_dog_id;

    for i in 1..6 loop
      v_captured_at := now() - ((6 - i) * interval '5 minutes');
      v_hr := 82 + floor(random() * 9 - 4)::int;
      v_rr := 20 + floor(random() * 5 - 2)::int;
      v_motion := round((0.110 + (random() * 0.140))::numeric, 3);
      
      if v_motion < 0.170 then
        v_posture := 'lying'::posture_type;
      else
        v_posture := 'sitting'::posture_type;
      end if;

      insert into public.telemetry_readings (
        device_id, dog_id, captured_at, received_at, heart_rate_bpm, respiratory_rate_bpm,
        motion_activity, posture, ambient_temperature_c, humidity_percent, is_valid, raw_payload
      )
      values (
        v_dummy_device_id, v_maxine_dog_id, v_captured_at, v_captured_at + interval '1 second',
        v_hr, v_rr, v_motion, v_posture,
        24.4 + round((random() * 0.8 - 0.4)::numeric, 1),
        51.8 + round((random() * 2.0 - 1.0)::numeric, 1),
        true,
        jsonb_build_object('simulated', true, 'baseline', true, 'point_index', i)
      )
      returning id into v_reading_id;

      v_score := round((0.10 + (random() * 0.12))::numeric, 2);

      insert into public.stress_classifications (
        dog_id, telemetry_reading_id, stress_level, score, confidence, reasons, model_version, created_at
      )
      values (
        v_maxine_dog_id, v_reading_id, 'calm'::stress_level, v_score, 0.950,
        '["Normal resting heart rate within baseline", "Low motion activity", "Resting posture detected"]'::jsonb,
        'rule-v1', v_captured_at
      );
    end loop;

    update public.devices set status = 'active', battery_percent = 95, last_seen_at = now() where id = v_dummy_device_id;
  end if;
end;
$$;
