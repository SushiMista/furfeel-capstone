import { expect, it } from "vitest";
import { formatDogAge } from "../src/lib/dogAge.ts";

const now = new Date(2026, 10, 5);

it("shows years, and months for puppies", () => {
  expect(formatDogAge("2023-11-05", now)).toBe("3 years old");
  expect(formatDogAge("2025-11-05", now)).toBe("1 year old");
  expect(formatDogAge("2026-03-01", now)).toBe("8 months old");
  expect(formatDogAge("2026-10-01", now)).toBe("1 month old");
  expect(formatDogAge("2026-10-20", now)).toBe("Under 1 month old");
});

it("doesn't count a birthday that hasn't happened yet this year", () => {
  expect(formatDogAge("2023-11-06", now)).toBe("2 years old");
});

it("stays empty for missing, invalid or future dates", () => {
  expect(formatDogAge(null, now)).toBeNull();
  expect(formatDogAge("not a date", now)).toBeNull();
  expect(formatDogAge("2027-01-01", now)).toBeNull();
});
