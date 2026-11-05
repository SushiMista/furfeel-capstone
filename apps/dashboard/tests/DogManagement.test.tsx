import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { DogManagement } from "../src/pages/dogs/DogManagement.tsx";

vi.mock("../src/lib/supabaseClient.ts", () => {
  const channel = { on: vi.fn().mockReturnThis(), subscribe: vi.fn().mockReturnThis() };
  return { supabase: { channel: () => channel, removeChannel: vi.fn() } };
});

const dog = {
  id: "dog-1",
  owner_user_id: "u1",
  name: "Biscuit",
  breed: "Beagle",
  sex: "male",
  weight_kg: 12,
  birthdate: null,
  photo_path: null,
  notes: null,
};

vi.mock("../src/lib/queries.ts", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/queries.ts")>()),
  fetchDogs: vi.fn(async () => [dog]),
  fetchDevicesReadOnly: vi.fn(async () => [
    { id: "d1", dog_id: "dog-1", device_code: "FURFEEL-DEV-0002", display_name: "Kennel collar", status: "active" },
  ]),
  fetchMonitoringBoard: vi.fn(async () => [
    { dog, latestClassification: { stress_level: "moderate" } },
  ]),
}));

vi.mock("../src/lib/adminQueries.ts", async (importOriginal) => ({
  ...(await importOriginal<typeof import("../src/lib/adminQueries.ts")>()),
  fetchAllUsers: vi.fn(async () => []),
}));

describe("Patient Dogs table", () => {
  it("shows status and collar name, and a row click opens the dog", async () => {
    render(
      <MemoryRouter initialEntries={["/patients"]}>
        <Routes>
          <Route path="/patients" element={<DogManagement />} />
          <Route path="/dogs/:dogId" element={<p>Dog page</p>} />
        </Routes>
      </MemoryRouter>,
    );

    expect(await screen.findByText("Kennel collar")).toHaveAttribute("title", "FURFEEL-DEV-0002");
    expect(screen.getByText(/moderate/i)).toBeInTheDocument();

    await userEvent.click(screen.getByText("No birth date"));
    expect(screen.getByText("Dog page")).toBeInTheDocument();
  });
});
