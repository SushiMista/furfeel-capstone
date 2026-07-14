import { describe, expect, it } from "vitest";
import { buildStressLabelInsert } from "../src/lib/queries.ts";
import type { StressClassification } from "../../../packages/shared/types/index.ts";

const classification: StressClassification = {
  id: "c1",
  dog_id: "dog1",
  telemetry_reading_id: "r1",
  stress_level: "moderate",
  score: 5,
  confidence: null,
  reasons: [],
  model_version: "rule-v1",
  created_at: "2026-07-11T08:00:00Z",
};

describe("buildStressLabelInsert (ground-truth semantics)", () => {
  it("records agreement when the vet confirms the model's level", () => {
    const insert = buildStressLabelInsert("dog1", "vet1", "moderate", classification, "");
    expect(insert.agreed_with_model).toBe(true);
    expect(insert.confirmed_level).toBe("moderate");
    expect(insert.classification_id).toBe("c1");
    expect(insert.telemetry_reading_id).toBe("r1");
    expect(insert.vet_user_id).toBe("vet1");
    expect(insert.note).toBeNull();
  });

  it("records an override when the vet picks a different level", () => {
    const insert = buildStressLabelInsert("dog1", "vet1", "high", classification, "  panting hard  ");
    expect(insert.agreed_with_model).toBe(false);
    expect(insert.confirmed_level).toBe("high");
    expect(insert.note).toBe("panting hard");
  });

  it("leaves agreement null when there is no model classification to compare", () => {
    const insert = buildStressLabelInsert("dog1", "vet1", "calm", null, "");
    expect(insert.agreed_with_model).toBeNull();
    expect(insert.classification_id).toBeNull();
    expect(insert.telemetry_reading_id).toBeNull();
  });
});
