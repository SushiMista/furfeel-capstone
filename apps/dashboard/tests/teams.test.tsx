import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { BrowserRouter } from "react-router-dom";
import { ClinicTeams } from "../src/pages/teams/ClinicTeams.tsx";
import * as queries from "../src/lib/queries.ts";

vi.mock("../src/lib/useAuth.ts", () => ({
  useAuth: () => ({
    session: { user: { id: "user-1", email: "vet@example.com" } },
    loading: false,
  }),
}));

vi.mock("../src/lib/useCurrentRole.ts", () => ({
  useCurrentRole: () => ({
    role: "admin",
    clinicId: null,
    loading: false,
  }),
}));

vi.mock("../src/lib/queries.ts", async () => {
  const actual = await vi.importActual<typeof queries>("../src/lib/queries.ts");
  return {
    ...actual,
    fetchClinicTeams: vi.fn().mockResolvedValue([
      {
        clinic: {
          id: "clinic-1",
          name: "Bethlehem Animal Clinic",
          address: "123 Main St",
          contact_number: "0917-123-4567",
        },
        members: [
          {
            id: "u-1",
            name: "Dr. Sarah Jenkins",
            email: "sarah@bethlehem.com",
            role: "veterinarian",
            clinic_id: "clinic-1",
            avatar_path: null,
            phone: "0917-111-2222",
            created_at: "2026-01-01T00:00:00Z",
          },
          {
            id: "u-2",
            name: "Mark Rivera",
            email: "mark@bethlehem.com",
            role: "vet_staff",
            clinic_id: "clinic-1",
            avatar_path: null,
            phone: null,
            created_at: "2026-02-01T00:00:00Z",
          },
        ],
        dogCount: 5,
        veterinarianCount: 1,
        vetStaffCount: 1,
      },
    ]),
  };
});

describe("ClinicTeams page", () => {
  it("renders partner clinic name and assigned team members", async () => {
    render(
      <BrowserRouter>
        <ClinicTeams />
      </BrowserRouter>,
    );

    expect(await screen.findByText("Clinic Teams & Staff Roster")).toBeInTheDocument();
    expect(screen.getAllByText("Bethlehem Animal Clinic").length).toBeGreaterThan(0);
    expect(screen.getByText("Dr. Sarah Jenkins")).toBeInTheDocument();
    expect(screen.getByText("Mark Rivera")).toBeInTheDocument();
    expect(screen.getAllByText("Veterinarian").length).toBeGreaterThan(0);
    expect(screen.getAllByText("Vet Staff").length).toBeGreaterThan(0);
  });
});
