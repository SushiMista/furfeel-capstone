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
  fetchMonitoringBoard: vi.fn(),
  fetchMonitoringBoardRowForDog: vi.fn(),
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
  vi.mocked(queries.fetchMonitoringBoard).mockResolvedValue([] as never);
  vi.mocked(queries.fetchMonitoringBoardRowForDog).mockResolvedValue({
    latestClassification: { stress_level: "high" },
    latestReading: { heart_rate_bpm: 132, respiratory_rate_bpm: 41, captured_at: "2026-11-05T08:00:00Z" },
    openAlertCount: 3,
  } as never);
});

describe("Messages", () => {
  it("lists dogs with the latest conversation first and an unread count", async () => {
    renderInbox();
    expect(await screen.findByLabelText("3 unread")).toBeInTheDocument();
    const names = screen.getAllByRole("listitem").map((item) => item.textContent);
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

  it("puts unread first, then the most stressed dogs, and filters to unread", async () => {
    const user = userEvent.setup();
    vi.mocked(queries.fetchDogs).mockResolvedValue([
      { id: "dog-1", name: "Biscuit" },
      { id: "dog-3", name: "Pepper" },
      { id: "dog-2", name: "Mochi" },
    ] as never);
    vi.mocked(queries.fetchMonitoringBoard).mockResolvedValue([
      { dog: { id: "dog-3" }, latestClassification: { stress_level: "high" } },
    ] as never);
    renderInbox();

    await screen.findByLabelText("3 unread");
    await waitFor(() =>
      expect(screen.getAllByRole("listitem").map((i) => i.textContent?.slice(0, 6))).toEqual([
        expect.stringContaining("Mochi"),
        expect.stringContaining("Pepper"),
        expect.stringContaining("Biscui"),
      ]),
    );

    await user.click(screen.getByRole("button", { name: "Unread 1" }));
    expect(screen.getAllByRole("listitem")).toHaveLength(1);
  });

  it("searches patients by name", async () => {
    const user = userEvent.setup();
    renderInbox();

    await user.type(await screen.findByLabelText("Search patients"), "bisc");
    expect(screen.getAllByRole("listitem")).toHaveLength(1);
    expect(screen.getByText("Biscuit")).toBeInTheDocument();

    await user.type(screen.getByLabelText("Search patients"), "zzz");
    expect(screen.getByText("No patients match your search.")).toBeInTheDocument();
  });

  it("shows the dog's status beside the chat", async () => {
    renderInbox("/messages?dog=dog-2");
    expect(await screen.findByText("132 bpm")).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Open dog" })).toHaveAttribute("href", "/dogs/dog-2");
  });

  it("describes a message with no text by what it contains", () => {
    expect(threadPreview({ ...thread, last_body: null, last_has_media: true })).toBe("Photo or video");
    expect(threadPreview({ ...thread, last_body: null, last_has_alert: true })).toBe("Shared an alert");
  });
});
