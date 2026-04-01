import { describe, expect, it } from "vitest";
import { buildProviderRegistry, createLocalFeatureFlagAdapter } from "./index";

describe("integrations registry", () => {
  it("enables configured local feature flags", async () => {
    const adapter = createLocalFeatureFlagAdapter(["magic-link-auth"]);
    await expect(adapter.isEnabled("magic-link-auth")).resolves.toBe(true);
    await expect(adapter.isEnabled("social-login")).resolves.toBe(false);
  });

  it("builds a provider registry from env", async () => {
    const registry = buildProviderRegistry({
      FEATURE_FLAGS_LOCAL: "magic-link-auth,social-login",
    });

    expect(registry.maps.provider).toBe("mapbox");
    await expect(registry.featureFlags.isEnabled("social-login")).resolves.toBe(true);
  });
});
