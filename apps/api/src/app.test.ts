import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { buildApp } from "./app";

let app: Awaited<ReturnType<typeof buildApp>>;

beforeAll(async () => {
  app = await buildApp();
});

afterAll(async () => {
  await app.close();
});

describe("api routes", () => {
  it("returns public runtime config", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/config/public",
    });

    expect(response.statusCode).toBe(200);
    expect(response.json().item.defaultMarket.code).toBe("AU");
  });

  it("returns filtered listings", async () => {
    const response = await app.inject({
      method: "GET",
      url: "/listings?state=NSW",
    });

    expect(response.statusCode).toBe(200);
    const payload = response.json();
    expect(payload.items.length).toBeGreaterThan(0);
    expect(payload.items.every((item: { address: { state: string } }) => item.address.state === "NSW")).toBe(true);
  });

  it("creates a saved property", async () => {
    const response = await app.inject({
      method: "POST",
      url: "/saved-properties",
      payload: {
        listingId: "listing-nsw-paddington",
        collection: "Test shortlist",
        tags: ["test"],
        status: "saved",
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.json().item.collection).toBe("Test shortlist");
  });
});
