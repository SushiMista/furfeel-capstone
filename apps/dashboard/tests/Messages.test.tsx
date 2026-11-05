import { beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { Messages, threadPreview } from "../src/pages/messages/Messages.tsx";
import * as queries from "../src/lib/queries.ts";

vi.mock("../src/lib/supabaseClient.ts", () => {
  const channel = { on: () => channel, subscribe: () => channel };
  return { supabase: { channel: () => channel, removeChannel: vi.fn() } };
});
vi.mock("../src/lib/useAuth.ts", () => ({
  useAuth: () => ({ session: { user: { id: "vet-1" } } }),
}));
vi.mock("../src/lib/queries.ts", () => ({
  fetchDogs: vi.fn(),
  fetchDogMessageThreads: vi.fn(),
  fetchDogMessages: vi.fn(),
  markDogMessagesRead: vi.fn().mockResolvedValue(undefined),
  sendDogMessage: vi.fn().mockResolvedValue(undefined),
  getMediaSignedUrl: vi.fn().mockResolvedValue("https://example.test/photo.jpg"),
}));

const thread = {
  dog_id: "dog-2",
  last_body: "He is pacing",
  last_has_media: false,
  last_has_alert: false,
  last_author_id: "owner-1",
  last_at: "2026-11-05T08:00:00Z",
  unread_count: 3,
};

const message = {
  id: "m1",
  dog_id: "dog-2",
  author_user_id: "owner-1",
  body: "He is pacing",
  media_path: null,
  media_type: null,
  edited_at: null,
  created_at: "2026-11-05T08:00:00Z",
  author: { name: "Joshua" },
  alert: { type: "moderate_stress", severity: "warning" },
  reading: { heart_rate_bpm: 87, ambient_temperature_c: 24.6, captured_at: "2026-11-05T07:59:00Z" },
};

function renderInbox(url = "/messages") {
  return render(
    <MemoryRouter initialEntries={[url]}>
      <Messages />
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.mocked(queries.fetchDogs).mockResolvedValue([
    { id: "dog-1", name: "Biscuit" },
    { id: "dog-2", name: "Mochi" },
  ] as never);
  vi.mocked(queries.fetchDogMessageThreads).mockResolvedValue([thread]);
  vi.mocked(queries.fetchDogMessages).mockResolvedValue([message] as never);
});

describe("Messages", () => {
  it("lists dogs with the latest conversation first and an unread count", async () => {
    renderInbox();
    expect(await screen.findByLabelText("3 unread")).toBeInTheDocument();
    const names = screen.getAllByRole("button").map((b) => b.textContent);
    expect(names[0]).toContain("Mochi");
    expect(names[1]).toContain("No messages yet");
  });

  it("opens a conversation, marks it read, and shows the attached alert", async () => {
    renderInbox("/messages?dog=dog-2");
    expect(await screen.findByText("Moderate stress alert")).toBeInTheDocument();
    expect(screen.getByText(/87 bpm/)).toBeInTheDocument();
    await waitFor(() =>
      expect(queries.markDogMessagesRead).toHaveBeenCalledWith(expect.anything(), "dog-2", "vet-1"),
    );
  });

  it("sends a reply as the signed-in vet", async () => {
    const user = userEvent.setup();
    renderInbox("/messages?dog=dog-2");
    await user.type(await screen.findByLabelText("Message about Mochi"), "Keep him somewhere quiet");
    await user.click(screen.getByRole("button", { name: "Send" }));
    await waitFor(() =>
      expect(queries.sendDogMessage).toHaveBeenCalledWith(
        expect.anything(),
        "dog-2",
        "vet-1",
        "Keep him somewhere quiet",
      ),
    );
  });

  it("describes a message with no text by what it contains", () => {
    expect(threadPreview({ ...thread, last_body: null, last_has_media: true })).toBe("Photo or video");
    expect(threadPreview({ ...thread, last_body: null, last_has_alert: true })).toBe("Shared an alert");
  });
});
