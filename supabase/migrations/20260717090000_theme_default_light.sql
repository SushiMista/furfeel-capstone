-- QA pass: new installs open in light mode (docs/04 Settings). Existing rows
-- keep whatever the user chose; only the default for new rows changes.
alter table public.user_settings alter column theme set default 'light';
