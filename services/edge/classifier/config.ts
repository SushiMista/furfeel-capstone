import rawConfig from "../../../packages/shared/classifier_config.json" with { type: "json" };
import type { ClassifierConfig } from "./types.ts";

// packages/shared/classifier_config.json is the single source of truth for every
// threshold and baseline the classifier uses. Do not hardcode thresholds here or
// in classify.ts — add/change them in the JSON file so a vet can tune them without
// touching code. See the "_disclaimer" key in that file for provenance.
export const defaultConfig: ClassifierConfig = rawConfig as unknown as ClassifierConfig;
