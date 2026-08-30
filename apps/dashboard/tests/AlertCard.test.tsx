import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { AlertCard } from "../src/components/AlertCard.tsx";
import type { Alert } from "../../../packages/shared/types/index.ts";

function alert(overrides: Partial<Alert> = {}): Alert {
  return {
    id: "a1",
    dog_id: "dog-1",
    classification_id: null,
    severity: "critical",
    type: "high_stress",
    message: "Stress level is high — requires review.",
    status: "open",
    acknowledged_by: null,
    acknowledged_at: null,
    created_at: "2026-07-11T08:00:00Z",
    ...overrides,
  };
}

describe("AlertCard", () => {
  it("shows an Acknowledge button for open alerts and calls the handler", async () => {
    const onAcknowledge = vi.fn().mockResolvedValue(undefined);
    render(
      <MemoryRouter>
        <AlertCard alert={alert()} onAcknowledge={onAcknowledge} />
      </MemoryRouter>,
    );

    await userEvent.click(screen.getByRole("button", { name: /acknowledge/i }));
    await waitFor(() => expect(onAcknowledge).toHaveBeenCalledTimes(1));
  });

  it("hides the button and fades once acknowledged", () => {
    const { container } = render(
      <MemoryRouter>
        <AlertCard
          alert={alert({ status: "acknowledged", acknowledged_by: "u1" })}
          onAcknowledge={vi.fn()}
        />
      </MemoryRouter>,
    );
    expect(screen.queryByRole("button", { name: /acknowledge/i })).not.toBeInTheDocument();
    expect(container.querySelector(".alert-acknowledged")).not.toBeNull();
    expect(screen.getAllByText(/acknowledged/i).length).toBeGreaterThan(0);
  });

  it("renders Investigate Dog link and Check Device link for device_offline alerts", () => {
    render(
      <MemoryRouter>
        <AlertCard
          alert={alert({
            type: "device_offline",
            message: "Device FURFEEL-DEV-0002 stopped sending data (last seen 2026-08-22 17:16 UTC).",
          })}
        />
      </MemoryRouter>,
    );

    expect(screen.getByText("Investigate Dog")).toBeInTheDocument();
    expect(screen.getByText("Check Device")).toBeInTheDocument();
    expect(screen.getByText(/2026-08-23 01:16 PST/)).toBeInTheDocument();
  });
});
