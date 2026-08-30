-- Fix the audit trigger function that crashes on 'system'::user_role
create or replace function public.log_user_audit_event()
returns trigger
language plpgsql
security definer
as $$
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
    -- FIX: Use a valid user_role (e.g. 'admin') instead of 'system' which isn't in the enum
    current_actor_role := coalesce(NEW.role, OLD.role, 'admin'::user_role);
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
$$;
