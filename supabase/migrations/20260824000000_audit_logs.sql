-- FurFeel Audit Logging System (docs/05 Admin Audit Logs).
-- Append-only audit log table for security, operational, and clinical events
-- across Veterinary Dashboard, Mobile App, Edge Functions, and System triggers.

create table public.audit_logs (
  id               uuid primary key default gen_random_uuid(),
  created_at       timestamptz not null default now(),
  actor_id         uuid references public.users (id) on delete set null,
  actor_email      text not null,
  actor_role       user_role not null,
  surface          text not null check (surface in ('dashboard', 'mobile', 'edge_function', 'system')),
  action           text not null,
  target_resource  text not null,
  target_id        text,
  clinic_id        uuid references public.clinics (id) on delete set null,
  details          jsonb default '{}'::jsonb,
  severity         text not null default 'info' check (severity in ('info', 'warning', 'critical'))
);

create index idx_audit_logs_created_at on public.audit_logs (created_at desc);
create index idx_audit_logs_actor_id on public.audit_logs (actor_id);
create index idx_audit_logs_surface on public.audit_logs (surface);
create index idx_audit_logs_action on public.audit_logs (action);
create index idx_audit_logs_clinic_id on public.audit_logs (clinic_id);

alter table public.audit_logs enable row level security;

-- SELECT Policy: Admins can view all audit logs.
-- Clinic staff can view logs related to their clinic.
create policy audit_logs_select_admin_or_clinic on public.audit_logs
  for select using (
    public.current_user_role() = 'admin'
    or (
      public.current_user_role() in ('vet_staff', 'veterinarian')
      and audit_logs.clinic_id is not null
      and audit_logs.clinic_id = (select u.clinic_id from public.users u where u.id = auth.uid())
    )
  );

-- INSERT Policy: Authenticated users can insert audit records.
create policy audit_logs_insert_authenticated on public.audit_logs
  for insert with check (
    auth.role() = 'authenticated'
    and (actor_id is null or actor_id = auth.uid())
  );

-- Note: No UPDATE or DELETE policies exist for audit_logs. Immutability guaranteed.

-- =========================================================================
-- Automatic Postgres Triggers for Core Admin Entities
-- =========================================================================

create or replace function public.log_user_audit_event()
returns trigger as $$
declare
  current_actor_id uuid;
  current_actor_email text;
  current_actor_role user_role;
begin
  current_actor_id := auth.uid();
  if current_actor_id is not null then
    select email, role into current_actor_email, current_actor_role
    from public.users where id = current_actor_id;
  end if;

  if current_actor_email is null then
    current_actor_email := coalesce(NEW.email, OLD.email, 'system@furfeel.local');
    current_actor_role := coalesce(NEW.role, OLD.role, 'system'::user_role);
  end if;

  if TG_OP = 'INSERT' then
    insert into public.audit_logs (actor_id, actor_email, actor_role, surface, action, target_resource, target_id, clinic_id, details, severity)
    values (
      current_actor_id,
      current_actor_email,
      current_actor_role,
      case when current_actor_id is null then 'system' else 'dashboard' end,
      'user.create',
      'users',
      NEW.id::text,
      NEW.clinic_id,
      jsonb_build_object('name', NEW.name, 'email', NEW.email, 'role', NEW.role),
      'info'
    );
  elsif TG_OP = 'UPDATE' then
    if OLD.role <> NEW.role or coalesce(OLD.clinic_id, '00000000-0000-0000-0000-000000000000'::uuid) <> coalesce(NEW.clinic_id, '00000000-0000-0000-0000-000000000000'::uuid) then
      insert into public.audit_logs (actor_id, actor_email, actor_role, surface, action, target_resource, target_id, clinic_id, details, severity)
      values (
        current_actor_id,
        current_actor_email,
        current_actor_role,
        'dashboard',
        'user.role_update',
        'users',
        NEW.id::text,
        NEW.clinic_id,
        jsonb_build_object('old_role', OLD.role, 'new_role', NEW.role, 'old_clinic_id', OLD.clinic_id, 'new_clinic_id', NEW.clinic_id),
        'warning'
      );
    end if;
  elsif TG_OP = 'DELETE' then
    insert into public.audit_logs (actor_id, actor_email, actor_role, surface, action, target_resource, target_id, clinic_id, details, severity)
    values (
      current_actor_id,
      current_actor_email,
      current_actor_role,
      'dashboard',
      'user.delete',
      'users',
      OLD.id::text,
      OLD.clinic_id,
      jsonb_build_object('deleted_email', OLD.email, 'deleted_role', OLD.role),
      'warning'
    );
  end if;
  return coalesce(NEW, OLD);
end;
$$ language plpgsql security definer;

create trigger trg_user_audit
  after insert or update or delete on public.users
  for each row execute function public.log_user_audit_event();
