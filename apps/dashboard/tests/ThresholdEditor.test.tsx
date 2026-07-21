import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ThresholdEditor } from "../src/components/ThresholdEditor.tsx";

vi.mock("../src/lib/supabaseClient.ts", () => ({ supabase: {} }));

const fetchDogBaselines = vi.fn();
const saveDogThresholds = vi.fn();
vi.mock("../src/lib/queries.ts", () => ({
  fetchDogBaselines: (...args: unknown[]) => fetchDogBaselines(...args),
  saveDogThresholds: (...args: unknown[]) => saveDogThresholds(...args),
}));

describe("ThresholdEditor", () => {
  beforeEach(() => {
    fetchDogBaselines.mockReset();
    saveDogThresholds.mockReset();
  });

  it("shows the global defaults when the dog has no override, and lets a vet set one", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    saveDogThresholds.mockResolvedValue({
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: null,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      threshold_mild_min: 1,
      threshold_moderate_min: null,
      threshold_high_min: null,
      updated_at: "2026-07-21T00:00:00Z",
    });

    render(<ThresholdEditor dogId="dog-1" />);

    // Defaults, cited rather than invented (CLAUDE.md guardrail).
    expect(await screen.findByText("Default · 2")).toBeInTheDocument();
    expect(screen.getByText("Default · 4")).toBeInTheDocument();
    expect(screen.getByText("Default · 7")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /save thresholds/i })).toBeDisabled();

    await userEvent.type(screen.getByLabelText("Mild starts at score"), "1");
    expect(screen.getByRole("button", { name: /save thresholds/i })).toBeEnabled();

    await userEvent.click(screen.getByRole("button", { name: /save thresholds/i }));

    await waitFor(() =>
      expect(saveDogThresholds).toHaveBeenCalledWith({}, "dog-1", {
        threshold_mild_min: 1,
        threshold_moderate_min: null,
        threshold_high_min: null,
      }),
    );
    expect(await screen.findByText("Custom · effective 1")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /reset to default/i })).toBeInTheDocument();
  });

  it("rejects out-of-order thresholds before saving", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    render(<ThresholdEditor dogId="dog-1" />);

    await screen.findByText("Default · 2");
    await userEvent.type(screen.getByLabelText("Mild starts at score"), "8");
    await userEvent.click(screen.getByRole("button", { name: /save thresholds/i }));

    expect(
      await screen.findByText(/mild < moderate < high/i),
    ).toBeInTheDocument();
    expect(saveDogThresholds).not.toHaveBeenCalled();
  });
});
