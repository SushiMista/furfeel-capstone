-- Trigger function to automatically create a dummy device and initial biotelemetry reading
-- for any newly registered dog, except if the dog is named "Biscuit" (which is reserved
-- for the physical ESP32 device).
create or replace function public.handle_new_dog()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_device_id uuid;
  v_reading_id uuid;
  v_device_code text;
begin
  -- Exclude Biscuit from auto-pairing a dummy device
  if lower(trim(new.name)) = 'biscuit' then
    return new;
  end if;

  -- Generate a unique dummy device code
  v_device_code := 'FF-DUMMY-' || upper(substring(new.id::text from 1 for 8));

  -- 1. Insert the dummy device
  insert into public.devices (dog_id, device_code, status, firmware_version, battery_percent)
  values (new.id, v_device_code, 'active', 'sim-v1', 95)
  returning id into v_device_id;

  -- 2. Insert exactly one row of dummy biotelemetry data
  insert into public.telemetry_readings (
    device_id, dog_id, captured_at, heart_rate_bpm, respiratory_rate_bpm,
    motion_activity, posture, ambient_temperature_c, humidity_percent,
    battery_percent, is_valid, raw_payload
  )
  values (
    v_device_id,
    new.id,
    now(),
    85, -- resting heart rate
    20, -- resting respiratory rate
    0.150, -- resting motion
    'lying'::posture_type,
    23.5, -- ambient temp
    50.0, -- humidity
    95,
    true,
    '{"simulated": true, "trigger": "auto_pair"}'::jsonb
  )
  returning id into v_reading_id;

  -- 3. Insert matching calm stress classification for the telemetry reading
  insert into public.stress_classifications (
    dog_id, telemetry_reading_id, stress_level, score, confidence, reasons, model_version
  )
  values (
    new.id,
    v_reading_id,
    'calm'::stress_level,
    0.0,
    1.0,
    '["Placeholder calm baseline data for dummy device"]'::jsonb,
    'rule-v1'
  );

  return new;
end;
$$;

-- Create the trigger
create or replace trigger on_dog_created
  after insert on public.dogs
  for each row execute function public.handle_new_dog();

-- Backfill existing dogs that are not 'Biscuit' and do not have any paired device
do $$
declare
  r record;
  v_device_id uuid;
  v_reading_id uuid;
  v_device_code text;
begin
  for r in 
    select d.id, d.name 
    from public.dogs d
    left join public.devices dev on dev.dog_id = d.id
    where dev.id is null and lower(trim(d.name)) <> 'biscuit'
  loop
    v_device_code := 'FF-DUMMY-' || upper(substring(r.id::text from 1 for 8));

    -- Create dummy device
    insert into public.devices (dog_id, device_code, status, firmware_version, battery_percent)
    values (r.id, v_device_code, 'active', 'sim-v1', 95)
    returning id into v_device_id;

    -- Create dummy telemetry reading
    insert into public.telemetry_readings (
      device_id, dog_id, captured_at, heart_rate_bpm, respiratory_rate_bpm,
      motion_activity, posture, ambient_temperature_c, humidity_percent,
      battery_percent, is_valid, raw_payload
    )
    values (
      v_device_id,
      r.id,
      now(),
      85,
      20,
      0.150,
      'lying'::posture_type,
      23.5,
      50.0,
      95,
      true,
      '{"simulated": true, "backfill": true}'::jsonb
    )
    returning id into v_reading_id;

    -- Create stress classification
    insert into public.stress_classifications (
      dog_id, telemetry_reading_id, stress_level, score, confidence, reasons, model_version
    )
    values (
      r.id,
      v_reading_id,
      'calm'::stress_level,
      0.0,
      1.0,
      '["Backfilled calm baseline data for dummy device"]'::jsonb,
      'rule-v1'
    );
  end loop;
end;
$$;
