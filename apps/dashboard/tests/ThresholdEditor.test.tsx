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

const NULL_OVERRIDES = {
  threshold_mild_min: null,
  threshold_moderate_min: null,
  threshold_high_min: null,
  hr_ratio_elevated_min: null,
  hr_ratio_moderate_min: null,
  hr_ratio_high_min: null,
  rr_ratio_elevated_min: null,
  rr_ratio_high_min: null,
  body_temp_elevated_c: null,
  body_temp_high_c: null,
  motion_elevated_min: null,
  motion_high_min: null,
  ambient_heat_c: null,
  humidity_heat_pct: null,
};

describe("ThresholdEditor", () => {
  beforeEach(() => {
    fetchDogBaselines.mockReset();
    saveDogThresholds.mockReset();
  });

  it("shows only the Score cutoffs category by default, categorized into tabs", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    render(<ThresholdEditor dogId="dog-1" />);

    expect(await screen.findByRole("tab", { name: "Score cutoffs" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
    // Score cutoffs are visible immediately...
    expect(screen.getByText("Default · 2")).toBeInTheDocument();
    // ...but another category's fields are not in the DOM at all -- this is
    // the point: nothing to scroll past until a vet asks for it.
    expect(screen.queryByLabelText("Elevated at")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Heart rate" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Ambient temperature" })).toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Humidity" })).toBeInTheDocument();
  });

  it("switches categories on tab click without losing an edit made in another one", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    render(<ThresholdEditor dogId="dog-1" />);
    await screen.findByText("Default · 2");

    await userEvent.type(screen.getByLabelText("Mild starts at score"), "1");
    await userEvent.click(screen.getByRole("tab", { name: "Heart rate" }));

    expect(await screen.findByText("Default · 1.15")).toBeInTheDocument();
    expect(screen.queryByLabelText("Mild starts at score")).not.toBeInTheDocument();

    await userEvent.click(screen.getByRole("tab", { name: "Score cutoffs" }));
    expect(await screen.findByDisplayValue("1")).toBeInTheDocument();
  });

  it("marks a category tab as dirty while viewing a different one", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    render(<ThresholdEditor dogId="dog-1" />);
    await screen.findByText("Default · 2");

    // Grab the button references *before* typing -- the dirty dot is
    // aria-hidden (decorative only, see component comment), so it can't be
    // found by accessible name once present; a captured DOM reference still
    // works fine across the re-render since React keeps the same node.
    const scoreCutoffsTab = screen.getByRole("tab", { name: "Score cutoffs" });
    const heartRateTab = screen.getByRole("tab", { name: "Heart rate" });

    await userEvent.type(screen.getByLabelText("Mild starts at score"), "1");
    expect(scoreCutoffsTab.querySelector("[aria-hidden='true']")).toBeInTheDocument();
    expect(heartRateTab.querySelector("[aria-hidden='true']")).not.toBeInTheDocument();

    await userEvent.click(heartRateTab);
  });

  it("shows the global defaults when the dog has no override, and lets a vet set one", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    saveDogThresholds.mockResolvedValue({
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: null,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      ...NULL_OVERRIDES,
      threshold_mild_min: 1,
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
        ...NULL_OVERRIDES,
        threshold_mild_min: 1,
      }),
    );
    expect(await screen.findByText("Custom · effective 1")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /reset to default/i })).toBeInTheDocument();
  });

  it("rejects out-of-order score cutoffs before saving", async () => {
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

  it("rejects an out-of-order per-variable tier before saving, even from a different starting tab", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    render(<ThresholdEditor dogId="dog-1" />);
    await screen.findByText("Default · 2");

    await userEvent.click(screen.getByRole("tab", { name: "Heart rate" }));
    // Elevated set above the (default) moderate floor -> tiers overlap.
    await userEvent.type(document.getElementById("hr_ratio_elevated_min")!, "2");
    await userEvent.click(screen.getByRole("button", { name: /save thresholds/i }));

    expect(await screen.findByText(/heart rate: elevated < moderate/i)).toBeInTheDocument();
    expect(saveDogThresholds).not.toHaveBeenCalled();
  });

  it("lets a vet override one signal's threshold independent of the others", async () => {
    fetchDogBaselines.mockResolvedValue(null);
    saveDogThresholds.mockResolvedValue({
      id: "b1",
      dog_id: "dog-1",
      resting_heart_rate_bpm: null,
      resting_respiratory_rate_bpm: null,
      normal_body_temperature_c: null,
      ...NULL_OVERRIDES,
      body_temp_elevated_c: 38.9,
      updated_at: "2026-07-21T00:00:00Z",
    });

    render(<ThresholdEditor dogId="dog-1" />);
    await screen.findByText("Default · 2");

    await userEvent.click(screen.getByRole("tab", { name: "Body temperature" }));
    await userEvent.type(document.getElementById("body_temp_elevated_c")!, "38.9");
    await userEvent.click(screen.getByRole("button", { name: /save thresholds/i }));

    await waitFor(() =>
      expect(saveDogThresholds).toHaveBeenCalledWith({}, "dog-1", {
        ...NULL_OVERRIDES,
        body_temp_elevated_c: 38.9,
      }),
    );
  });
});
