import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import { Login } from "../src/pages/login/Login.tsx";

describe("Login", () => {
  it("renders email/password fields and a submit button", () => {
    render(<Login />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /sign in/i })).toBeInTheDocument();
  });
});
