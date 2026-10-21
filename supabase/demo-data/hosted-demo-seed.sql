-- ClinicFlow synthetic demo data for a dedicated non-production Supabase project.
-- Apply the repository migrations first. Never run this against production.
--
-- Before running:
-- 1. Run create-demo-users.mjs locally with the documented environment
--    variables, or create these ten users in Supabase Dashboard >
--    Authentication > Users using disposable passwords.
-- 2. Replace v_confirm_non_production with true only after confirming the
--    Supabase project is a dedicated demo/staging project.
-- 3. Run the entire script in Supabase SQL Editor.
--
-- This script does not create Auth users, change passwords, upload files, or
-- insert clinical notes/prescriptions. It sets application roles using the
-- privileged SQL Editor connection. All queue symptoms and walk-in details
-- below are explicitly synthetic.
--
-- Auth users created by the companion script:
--   clinicflow.demo.superadmin@example.test
--   clinicflow.demo.north.admin@example.test
--   clinicflow.demo.north.doctor@example.test
--   clinicflow.demo.north.reception@example.test
--   clinicflow.demo.north.patient1@example.test
--   clinicflow.demo.north.patient2@example.test
--   clinicflow.demo.south.admin@example.test
--   clinicflow.demo.south.doctor@example.test
--   clinicflow.demo.south.reception@example.test
--   clinicflow.demo.south.patient1@example.test
--
-- Re-running is safe for these fixed demo records. Existing records outside
-- this namespaced fixture are not deleted.

BEGIN;

DO $seed$
DECLARE
  v_confirm_non_production boolean := true; -- set to true only after confirming this is a dedicated non-production project
  v_email text;
  v_matches integer;

  v_super_admin uuid;
  v_north_admin uuid;
  v_north_doctor uuid;
  v_north_reception uuid;
  v_north_patient1 uuid;
  v_north_patient2 uuid;
  v_south_admin uuid;
  v_south_doctor uuid;
  v_south_reception uuid;
  v_south_patient1 uuid;

  v_north_clinic constant uuid := 'c1f10000-0000-4000-8000-000000000001';
  v_south_clinic constant uuid := 'c1f10000-0000-4000-8000-000000000002';
  v_north_schedule constant uuid := 'c1f10000-0000-4000-8000-000000000011';
  v_south_schedule constant uuid := 'c1f10000-0000-4000-8000-000000000012';
  v_north_session constant uuid := 'c1f10000-0000-4000-8000-000000000021';
  v_south_session constant uuid := 'c1f10000-0000-4000-8000-000000000022';
  v_north_patient1_entry constant uuid := 'c1f10000-0000-4000-8000-000000000031';
  v_north_patient2_entry constant uuid := 'c1f10000-0000-4000-8000-000000000032';
  v_north_walk_in constant uuid := 'c1f10000-0000-4000-8000-000000000041';
  v_north_walk_in_entry constant uuid := 'c1f10000-0000-4000-8000-000000000042';
  v_south_patient1_entry constant uuid := 'c1f10000-0000-4000-8000-000000000051';
  v_session_date date := current_date + 1;
  v_session_start timestamptz := ((current_date + 1) + time '09:00')::timestamptz;
  v_session_end timestamptz := ((current_date + 1) + time '17:00')::timestamptz;
BEGIN
  IF NOT v_confirm_non_production THEN
    RAISE EXCEPTION
      'Safety stop: confirm this is a dedicated non-production project, then set v_confirm_non_production to true.';
  END IF;

  FOREACH v_email IN ARRAY ARRAY[
    'clinicflow.demo.superadmin@example.test',
    'clinicflow.demo.north.admin@example.test',
    'clinicflow.demo.north.doctor@example.test',
    'clinicflow.demo.north.reception@example.test',
    'clinicflow.demo.north.patient1@example.test',
    'clinicflow.demo.north.patient2@example.test',
    'clinicflow.demo.south.admin@example.test',
    'clinicflow.demo.south.doctor@example.test',
    'clinicflow.demo.south.reception@example.test',
    'clinicflow.demo.south.patient1@example.test'
  ] LOOP
    SELECT count(*) INTO v_matches
    FROM auth.users
    WHERE lower(email) = lower(v_email);

    IF v_matches <> 1 THEN
      RAISE EXCEPTION
        'Expected exactly one Auth user for %, found %.',
        v_email, v_matches;
    END IF;
  END LOOP;

  SELECT id INTO STRICT v_super_admin
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.superadmin@example.test';
  SELECT id INTO STRICT v_north_admin
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.north.admin@example.test';
  SELECT id INTO STRICT v_north_doctor
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.north.doctor@example.test';
  SELECT id INTO STRICT v_north_reception
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.north.reception@example.test';
  SELECT id INTO STRICT v_north_patient1
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.north.patient1@example.test';
  SELECT id INTO STRICT v_north_patient2
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.north.patient2@example.test';
  SELECT id INTO STRICT v_south_admin
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.south.admin@example.test';
  SELECT id INTO STRICT v_south_doctor
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.south.doctor@example.test';
  SELECT id INTO STRICT v_south_reception
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.south.reception@example.test';
  SELECT id INTO STRICT v_south_patient1
  FROM auth.users WHERE lower(email) = 'clinicflow.demo.south.patient1@example.test';

  IF EXISTS (
    SELECT 1
    FROM unnest(ARRAY[
      v_super_admin, v_north_admin, v_north_doctor, v_north_reception,
      v_north_patient1, v_north_patient2, v_south_admin, v_south_doctor,
      v_south_reception, v_south_patient1
    ]) AS ids(auth_id)
    WHERE NOT EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = ids.auth_id
    )
  ) THEN
    RAISE EXCEPTION
      'A demo Auth user has no ClinicFlow profile. Confirm the identity migration and profile trigger are installed.';
  END IF;

  INSERT INTO public.clinics (id, name, slug, address, active)
  VALUES
    (v_north_clinic, 'ClinicFlow Demo North', 'clinicflow-demo-north',
      '100 Synthetic Way, Demo City', true),
    (v_south_clinic, 'ClinicFlow Demo South', 'clinicflow-demo-south',
      '200 Example Avenue, Demo City', true)
  ON CONFLICT (slug) DO NOTHING;

  IF NOT EXISTS (
    SELECT 1 FROM public.clinics
    WHERE id = v_north_clinic AND slug = 'clinicflow-demo-north'
  ) OR NOT EXISTS (
    SELECT 1 FROM public.clinics
    WHERE id = v_south_clinic AND slug = 'clinicflow-demo-south'
  ) THEN
    RAISE EXCEPTION
      'A demo clinic slug or fixed seed ID is already used by another row; no fixture data was committed.';
  END IF;

  UPDATE public.profiles
  SET full_name = 'Demo Super Admin', role = 'super_admin', updated_at = now()
  WHERE id = v_super_admin;
  UPDATE public.profiles
  SET full_name = 'North Demo Admin', role = 'clinic_admin', updated_at = now()
  WHERE id = v_north_admin;
  UPDATE public.profiles
  SET full_name = 'North Demo Doctor', role = 'doctor', updated_at = now()
  WHERE id = v_north_doctor;
  UPDATE public.profiles
  SET full_name = 'North Demo Reception', role = 'receptionist', updated_at = now()
  WHERE id = v_north_reception;
  UPDATE public.profiles
  SET full_name = 'North Demo Patient One', role = 'patient', updated_at = now()
  WHERE id = v_north_patient1;
  UPDATE public.profiles
  SET full_name = 'North Demo Patient Two', role = 'patient', updated_at = now()
  WHERE id = v_north_patient2;
  UPDATE public.profiles
  SET full_name = 'South Demo Admin', role = 'clinic_admin', updated_at = now()
  WHERE id = v_south_admin;
  UPDATE public.profiles
  SET full_name = 'South Demo Doctor', role = 'doctor', updated_at = now()
  WHERE id = v_south_doctor;
  UPDATE public.profiles
  SET full_name = 'South Demo Reception', role = 'receptionist', updated_at = now()
  WHERE id = v_south_reception;
  UPDATE public.profiles
  SET full_name = 'South Demo Patient One', role = 'patient', updated_at = now()
  WHERE id = v_south_patient1;

  INSERT INTO public.clinic_memberships (clinic_id, user_id, role)
  VALUES
    (v_north_clinic, v_super_admin, 'super_admin'),
    (v_south_clinic, v_super_admin, 'super_admin'),
    (v_north_clinic, v_north_admin, 'clinic_admin'),
    (v_north_clinic, v_north_doctor, 'doctor'),
    (v_north_clinic, v_north_reception, 'receptionist'),
    (v_south_clinic, v_south_admin, 'clinic_admin'),
    (v_south_clinic, v_south_doctor, 'doctor'),
    (v_south_clinic, v_south_reception, 'receptionist')
  ON CONFLICT (clinic_id, user_id) DO UPDATE
  SET role = EXCLUDED.role;

  INSERT INTO public.doctor_schedules (
    id, clinic_id, doctor_id, weekday, starts_at, ends_at,
    consultation_minutes, online_capacity, walk_in_reserve, active
  )
  VALUES
    (v_north_schedule, v_north_clinic, v_north_doctor,
      extract(dow FROM v_session_date)::smallint, time '09:00', time '17:00',
      10, 12, 8, true),
    (v_south_schedule, v_south_clinic, v_south_doctor,
      extract(dow FROM v_session_date)::smallint, time '09:00', time '17:00',
      10, 12, 8, true)
  ON CONFLICT (id) DO UPDATE SET
    clinic_id = EXCLUDED.clinic_id,
    doctor_id = EXCLUDED.doctor_id,
    weekday = EXCLUDED.weekday,
    starts_at = EXCLUDED.starts_at,
    ends_at = EXCLUDED.ends_at,
    consultation_minutes = EXCLUDED.consultation_minutes,
    online_capacity = EXCLUDED.online_capacity,
    walk_in_reserve = EXCLUDED.walk_in_reserve,
    active = EXCLUDED.active,
    updated_at = now();

  INSERT INTO public.queue_sessions (
    id, clinic_id, doctor_id, schedule_id, session_date, starts_at, ends_at,
    online_capacity, walk_in_reserve, status
  )
  VALUES
    (v_north_session, v_north_clinic, v_north_doctor, v_north_schedule,
      v_session_date, v_session_start, v_session_end, 12, 8, 'open'),
    (v_south_session, v_south_clinic, v_south_doctor, v_south_schedule,
      v_session_date, v_session_start, v_session_end, 12, 8, 'open')
  ON CONFLICT (id) DO UPDATE SET
    clinic_id = EXCLUDED.clinic_id,
    doctor_id = EXCLUDED.doctor_id,
    schedule_id = EXCLUDED.schedule_id,
    session_date = EXCLUDED.session_date,
    starts_at = EXCLUDED.starts_at,
    ends_at = EXCLUDED.ends_at,
    online_capacity = EXCLUDED.online_capacity,
    walk_in_reserve = EXCLUDED.walk_in_reserve,
    status = 'open';

  INSERT INTO public.patient_medical_histories (id, patient_id, symptoms, source)
  VALUES
    ('c1f10000-0000-4000-8000-000000000061', v_north_patient1,
      'DEMO ONLY: synthetic queue registration sample; not a real complaint.',
      'patient'),
    ('c1f10000-0000-4000-8000-000000000062', v_north_patient2,
      'DEMO ONLY: synthetic queue registration sample; not a real complaint.',
      'patient'),
    ('c1f10000-0000-4000-8000-000000000063', v_south_patient1,
      'DEMO ONLY: synthetic queue registration sample; not a real complaint.',
      'patient')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.walk_in_patients (id, full_name, phone, symptoms)
  VALUES (v_north_walk_in, 'DEMO ONLY - Walk-in Sample', '0000000000',
    'DEMO ONLY: synthetic walk-in sample; not a real complaint.')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.queue_entries (
    id, session_id, patient_id, walk_in_patient_id, token, status, source,
    urgency, estimated_minutes
  )
  VALUES
    (v_north_patient1_entry, v_north_session, v_north_patient1, null,
      1, 'waiting', 'online', 'standard', 10),
    (v_north_patient2_entry, v_north_session, v_north_patient2, null,
      2, 'waiting', 'online', 'standard', 10),
    (v_north_walk_in_entry, v_north_session, null, v_north_walk_in,
      3, 'waiting', 'walk_in', 'standard', 10),
    (v_south_patient1_entry, v_south_session, v_south_patient1, null,
      1, 'waiting', 'online', 'standard', 10)
  ON CONFLICT (id) DO NOTHING;
END;
$seed$;

COMMIT;

SELECT c.name AS clinic, s.session_date, s.status,
       count(e.id) AS seeded_queue_entries
FROM public.clinics c
JOIN public.queue_sessions s ON s.clinic_id = c.id
LEFT JOIN public.queue_entries e ON e.session_id = s.id
WHERE c.slug IN ('clinicflow-demo-north', 'clinicflow-demo-south')
  AND s.id IN (
    'c1f10000-0000-4000-8000-000000000021',
    'c1f10000-0000-4000-8000-000000000022'
  )
GROUP BY c.name, s.session_date, s.status
ORDER BY c.name;
