-- Full CRUD on the owner's own conversation (docs/04 module 5 observation
-- thread). Until now media_submissions only had select/insert/update
-- (update scoped to clinic review columns) — an owner had no way to retract
-- a submission they regretted sharing. media_messages only had
-- select/insert — no owner could edit a typo or delete a reply.
--
-- Scope stays tight: an owner may only delete their OWN submission, and only
-- edit/delete their OWN messages (author_user_id = auth.uid()) — never a
-- clinic member's. Clinician review notes (media_submissions.review_note)
-- and clinician-authored messages stay read-only to the owner by omission:
-- no owner-scoped update/delete policy touches either.

create policy media_delete_owner on media_submissions
  for delete using (submitted_by_user_id = auth.uid());

create policy media_messages_update_author on media_messages
  for update using (author_user_id = auth.uid())
  with check (author_user_id = auth.uid());

create policy media_messages_delete_author on media_messages
  for delete using (author_user_id = auth.uid());
