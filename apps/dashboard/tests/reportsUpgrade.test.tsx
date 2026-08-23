import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import { Reports } from "../src/pages/reports/Reports.tsx";
import * as queries from "../src/lib/queries.ts";

vi.mock("../src/lib/useAuth.ts", () => ({
  useAuth: () => ({
    session: { user: { id: "vet-1", email: "vet@example.com" } },
    loading: false,
  }),
}));

global.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
};

vi.mock("../src/lib/queries.ts", async () => {
  const actual = await vi.importActual<typeof queries>("../src/lib/queries.ts");
  return {
    ...actual,
    fetchDogs: vi.fn().mockResolvedValue([
      { id: "dog-1", name: "Biscuit", breed: "Golden Retriever" },
      { id: "dog-2", name: "Bochi Day", breed: "Poodle" },
    ]),
    fetchTelemetrySince: vi.fn().mockResolvedValue([
      {
        id: "t-1",
        dog_id: "dog-1",
        heart_rate_bpm: 80,
        respiratory_rate_brpm: 22,
        temperature_celsius: 38.4,
        ambient_temperature_celsius: 24.5,
        humidity_percent: 55,
        motion_index: 0.15,
        captured_at: new Date().toISOString(),
      },
    ]),
    fetchClassificationsSince: vi.fn().mockResolvedValue([
      {
        id: "c-1",
        dog_id: "dog-1",
        stress_level: "calm",
        confidence: 0.95,
        created_at: new Date().toISOString(),
      },
    ]),
    fetchAlertsSince: vi.fn().mockResolvedValue([]),
    getMediaSignedUrl: vi.fn().mockResolvedValue(null),
  };
});

vi.mock("../src/lib/adminQueries.ts", () => ({
  fetchClinics: vi.fn().mockResolvedValue([]),
}));

describe("Reports Page Upgrade", () => {
  it("renders searchable patient finder and separated clinical metric sections", async () => {
    render(
      <BrowserRouter>
        <Reports />
      </BrowserRouter>,
    );

    expect(await screen.findByText("Analytics & Reports")).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Search dog by name or breed...")).toBeInTheDocument();
    expect(await screen.findByText("Physiological Vital Signs")).toBeInTheDocument();
    expect(await screen.findByText("Physical Movement & Activity")).toBeInTheDocument();
    expect(await screen.findByText("Ambient Environment Context")).toBeInTheDocument();
  });
});
