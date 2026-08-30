-- FurFeel Bug and Error Reports Intake System (Admin & Mobile).
-- Stores bug, crash, UI, and technical error reports submitted by users.

create table public.bug_reports (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.users (id) on delete set null,
  reporter_name   text not null,
  reporter_email  text not null,
  title           text not null,
  description     text not null,
  category        text not null default 'bug' check (category in ('bug', 'ui_issue', 'device_connection', 'telemetry_error', 'crash', 'other')),
  severity        text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  status          text not null default 'open' check (status in ('open', 'in_progress', 'resolved', 'dismissed')),
  app_version     text not null default '1.0.0',
  platform        text not null default 'Mobile App',
  stack_trace     text,
  admin_notes     text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index idx_bug_reports_created_at on public.bug_reports (created_at desc);
create index idx_bug_reports_status on public.bug_reports (status);
create index idx_bug_reports_severity on public.bug_reports (severity);
create index idx_bug_reports_category on public.bug_reports (category);
create index idx_bug_reports_user_id on public.bug_reports (user_id);

alter table public.bug_reports enable row level security;

-- SELECT Policy: Admins can view all bug reports; users can view their own.
create policy bug_reports_select on public.bug_reports
  for select using (
    public.current_user_role() = 'admin'
    or (auth.uid() is not null and user_id = auth.uid())
  );

-- INSERT Policy: Authenticated users can submit bug reports.
create policy bug_reports_insert on public.bug_reports
  for insert with check (
    auth.role() = 'authenticated'
  );

-- UPDATE Policy: Only Admins can update bug report status and resolution notes.
create policy bug_reports_update_admin on public.bug_reports
  for update using (
    public.current_user_role() = 'admin'
  );

-- DELETE Policy: Only Admins can delete bug reports.
create policy bug_reports_delete_admin on public.bug_reports
  for delete using (
    public.current_user_role() = 'admin'
  );

-- Trigger to auto-update updated_at timestamp
create or replace function public.update_bug_reports_updated_at()
returns trigger as $$
begin
  NEW.updated_at = now();
  return NEW;
end;
$$ language plpgsql;

create trigger trg_bug_reports_updated_at
  before update on public.bug_reports
  for each row execute function public.update_bug_reports_updated_at();
