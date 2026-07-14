import { describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
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
    render(<AlertCard alert={alert()} onAcknowledge={onAcknowledge} />);

    await userEvent.click(screen.getByRole("button", { name: /acknowledge/i }));
    await waitFor(() => expect(onAcknowledge).toHaveBeenCalledTimes(1));
  });

  it("hides the button and fades once acknowledged", () => {
    const { container } = render(
      <AlertCard
        alert={alert({ status: "acknowledged", acknowledged_by: "u1" })}
        onAcknowledge={vi.fn()}
      />,
    );
    expect(screen.queryByRole("button")).not.toBeInTheDocument();
    expect(container.querySelector(".alert-acknowledged")).not.toBeNull();
    expect(screen.getByText(/acknowledged/i)).toBeInTheDocument();
  });
});
