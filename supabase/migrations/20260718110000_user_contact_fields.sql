-- Contact fields for the owner profile (docs/04 Profile/Account): the Phone
-- Number and Emergency Contact rows were UI stubs. Additive columns on users;
-- users_update_own already permits own-row updates (role/clinic stay pinned),
-- and clinic staff being able to read an owner's contact info via the
-- existing users_select policies is intentional — that's who calls them.
alter table users add column phone text;
alter table users add column emergency_contact text;
