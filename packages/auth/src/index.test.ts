import { describe, expect, it } from "vitest";
import { can, hashPassword, signUpSchema, verifyPassword } from "./index.js";

describe("auth package", () => {
  it("validates signup payloads", () => {
    const parsed = signUpSchema.parse({
      displayName: "Jordan Buyer",
      email: "jordan@example.com",
      password: "StrongPassword1",
      role: "buyer",
    });

    expect(parsed.email).toBe("jordan@example.com");
  });

  it("enforces role permissions", () => {
    expect(can("buyer", "offer:create")).toBe(true);
    expect(can("buyer", "rules:update")).toBe(false);
  });

  it("hashes and verifies passwords", async () => {
    const hash = await hashPassword("StrongPassword1");
    await expect(verifyPassword("StrongPassword1", hash)).resolves.toBe(true);
  });
});
