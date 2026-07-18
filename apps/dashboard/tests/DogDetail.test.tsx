import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { DogDetail } from "../src/pages/dog_detail/DogDetail.tsx";

// The page owns a Realtime subscription; a chainable stub stands in for it.
vi.mock("../src/lib/supabaseClient.ts", () => {
  const channel = { on: vi.fn().mockReturnThis(), subscribe: vi.fn().mockReturnThis() };
  return { supabase: { channel: () => channel, removeChannel: vi.fn() } };
});

vi.mock("../src/lib/useAuth.ts", () => ({ useAuth: () => ({ session: null }) }));

vi.mock("../src/lib/queries.ts", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/queries.ts")>()),
  fetchDog: vi.fn().mockResolvedValue({
    id: "dog-1",
    owner_user_id: "u1",
    clinic_id: "clinic-1",
    name: "Biscuit",
    breed: "Golden Retriever",
    birthdate: null,
    sex: null,
    weight_kg: null,
    notes: null,
    photo_path: null,
    created_at: "2026-07-01T00:00:00Z",
  }),
  fetchTelemetryHistory: vi.fn().mockResolvedValue([]),
  fetchClassificationHistory: vi.fn().mockResolvedValue([]),
  fetchDailyStressSummary: vi.fn().mockResolvedValue([]),
  fetchRecentAlerts: vi.fn().mockResolvedValue([
    {
      id: "a1",
      dog_id: "dog-1",
      classification_id: null,
      severity: "critical",
      type: "high_stress",
      message: "Biscuit is showing high stress",
      status: "open",
      acknowledged_by: null,
      acknowledged_at: null,
      created_at: "2026-07-18T08:00:00Z",
    },
  ]),
}));

function renderPage() {
  return render(
    <MemoryRouter initialEntries={["/dogs/dog-1"]}>
      <Routes>
        <Route path="/dogs/:dogId" element={<DogDetail />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe("DogDetail section tabs (docs/05 information architecture)", () => {
  it("defaults to Alerts with an open-count badge, and switches sections on tab click", async () => {
    renderPage();

    // Hero + default tab: the alert list is visible, telemetry is not.
    expect(await screen.findByRole("heading", { name: /Biscuit/ })).toBeInTheDocument();
    expect(screen.getByText("Biscuit is showing high stress")).toBeInTheDocument();
    expect(screen.queryByText("Live telemetry", { selector: "h3, [class*=title]" })).not.toBeInTheDocument();

    const alertsTab = screen.getByRole("tab", { name: /Alerts/ });
    expect(alertsTab).toHaveAttribute("aria-selected", "true");
    expect(alertsTab).toHaveTextContent("1"); // open-alert badge

    // Switching tabs swaps the section without losing the hero.
    await userEvent.click(screen.getByRole("tab", { name: "Live telemetry" }));
    expect(screen.queryByText("Biscuit is showing high stress")).not.toBeInTheDocument();
    expect(screen.getByRole("tab", { name: "Live telemetry" })).toHaveAttribute(
      "aria-selected",
      "true",
    );
  });
});
