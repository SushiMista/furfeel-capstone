-- Per-dog classifier threshold overrides (docs/08 AI Classification Pipeline):
-- dogs vary by size class, so one global score->level cutoff set is wrong for
-- many of them. dog_baselines is already per-dog, already clinic-scoped
-- (dog_baselines_select/insert/update RLS gates on is_clinic_member), and
-- already read by the classifier's baseline resolver -- these are three more
-- nullable columns on that same row rather than a new table + new policies.
-- NULL (the default) means "use the global default from
-- packages/shared/classifier_config.json.level_thresholds", exactly like the
-- existing baseline columns.
--
-- Three cut points instead of four (min, max) pairs: calm is implicit
-- (everything below threshold_mild_min), and each level's max is simply the
-- next level's min, so redundant boundaries can't drift out of sync.

alter table dog_baselines
  add column threshold_mild_min smallint,
  add column threshold_moderate_min smallint,
  add column threshold_high_min smallint;

alter table dog_baselines
  add constraint dog_baselines_thresholds_ordered check (
    (threshold_mild_min is null or threshold_moderate_min is null
      or threshold_mild_min < threshold_moderate_min)
    and (threshold_moderate_min is null or threshold_high_min is null
      or threshold_moderate_min < threshold_high_min)
    and (threshold_mild_min is null or threshold_high_min is null
      or threshold_mild_min < threshold_high_min)
  );
