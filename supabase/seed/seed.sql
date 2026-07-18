-- FurFeel local dev seed data: 1 clinic, 1 owner, 1 vet, 1 dog, 1 device, 1 dog_baselines row.
--
-- Auth users are inserted directly into auth.users so the on_auth_user_created trigger
-- fires and creates the matching public.users row (default role 'owner'); the vet is then
-- promoted to 'veterinarian' and assigned to the clinic.
--
-- IMPORTANT: GoTrue's login path does non-null-safe scans over the token columns, so every
-- token/varchar column must be '' (empty string), NOT NULL, or password logins fail with
-- "Database error querying schema". Each user also needs a matching auth.identities row
-- with provider 'email' or newer GoTrue versions won't treat email/password as enabled
-- for the account. Credentials: owner@example.com / vet@example.com, password "password123".

insert into public.clinics (id, name, address, contact_number)
values (
  '00000000-0000-0000-0000-000000000001',
  'Sunrise Veterinary Clinic',
  '123 Bark Ave, Springfield',
  '+1-555-0100'
);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at,
  recovery_token, recovery_sent_at, email_change_token_new, email_change,
  email_change_sent_at, email_change_token_current, email_change_confirm_status,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin, created_at, updated_at
) values
(
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'owner@example.com',
  crypt('password123', gen_salt('bf')),
  now(), null, '', null,
  '', null, '', '',
  null, '', 0,
  '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{"name":"Jamie Rivera"}',
  false, now(), now()
),
(
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'vet@example.com',
  crypt('password123', gen_salt('bf')),
  now(), null, '', null,
  '', null, '', '',
  null, '', 0,
  '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{"name":"Dr. Alex Kim"}',
  false, now(), now()
);

insert into auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
) values
(
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002',
  '{"sub":"00000000-0000-0000-0000-000000000002","email":"owner@example.com","email_verified":true,"phone_verified":false}',
  'email',
  now(), now(), now()
),
(
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000005',
  '00000000-0000-0000-0000-000000000005',
  '{"sub":"00000000-0000-0000-0000-000000000005","email":"vet@example.com","email_verified":true,"phone_verified":false}',
  'email',
  now(), now(), now()
);

update public.users
set role = 'veterinarian', clinic_id = '00000000-0000-0000-0000-000000000001'
where email = 'vet@example.com';

-- Admin account so the dashboard's Admin module (docs/05 §4) is reachable in
-- dev. Same insert pattern as above; promoted to 'admin' after the trigger
-- creates its public.users row. Credentials: admin@example.com / password123.
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at,
  recovery_token, recovery_sent_at, email_change_token_new, email_change,
  email_change_sent_at, email_change_token_current, email_change_confirm_status,
  phone_change, phone_change_token, reauthentication_token,
  raw_app_meta_data, raw_user_meta_data,
  is_super_admin, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000008',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated',
  'admin@example.com',
  crypt('password123', gen_salt('bf')),
  now(), null, '', null,
  '', null, '', '',
  null, '', 0,
  '', '', '',
  '{"provider":"email","providers":["email"]}',
  '{"name":"FurFeel Admin"}',
  false, now(), now()
);

insert into auth.identities (
  id, provider_id, user_id, identity_data, provider,
  last_sign_in_at, created_at, updated_at
) values (
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000008',
  '00000000-0000-0000-0000-000000000008',
  '{"sub":"00000000-0000-0000-0000-000000000008","email":"admin@example.com","email_verified":true,"phone_verified":false}',
  'email',
  now(), now(), now()
);

update public.users set role = 'admin' where email = 'admin@example.com';

-- Two dogs on the same clinic proves the multi-dog monitoring board (docs/05).
insert into public.dogs (id, owner_user_id, clinic_id, name, breed, birthdate, sex, weight_kg, notes)
values
(
  '00000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'Biscuit',
  'Golden Retriever',
  '2022-03-15',
  'male',
  28.50,
  'Friendly, slightly anxious at vet visits.'
),
(
  '00000000-0000-0000-0000-000000000006',
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000001',
  'Mochi',
  'Shiba Inu',
  '2023-08-02',
  'female',
  9.80,
  'Independent; dislikes thunderstorms.'
);

insert into public.devices (id, dog_id, device_code, status, firmware_version)
values
(
  '00000000-0000-0000-0000-000000000004',
  '00000000-0000-0000-0000-000000000003',
  'FURFEEL-DEV-0001',
  'active',
  '0.1.0'
),
-- Unassigned device so mobile Device Pairing can be exercised end to end.
(
  '00000000-0000-0000-0000-000000000007',
  null,
  'FURFEEL-DEV-0002',
  'inactive',
  '0.1.0'
);

insert into public.dog_baselines (dog_id, resting_heart_rate_bpm, resting_respiratory_rate_bpm, normal_body_temperature_c)
values
('00000000-0000-0000-0000-000000000003', 90, 20, 38.5),
('00000000-0000-0000-0000-000000000006', 100, 24, 38.6);

-- Explicit user_settings rows for the seed users (the on_auth_user_created
-- trigger also creates them; idempotent either way).
insert into public.user_settings (user_id)
values
('00000000-0000-0000-0000-000000000002'),
('00000000-0000-0000-0000-000000000005'),
('00000000-0000-0000-0000-000000000008')
on conflict (user_id) do nothing;
