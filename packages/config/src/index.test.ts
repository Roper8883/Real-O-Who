import { describe, expect, it } from "vitest";
import {
  buildPublicRuntimeConfig,
  getActiveMarkets,
  getMarketConfig,
  loadEnv,
  parseTargetMarkets,
} from "./index";

describe("config package", () => {
  it("loads defaults for local development", () => {
    const env = loadEnv({});
    expect(env.DEFAULT_MARKET).toBe("AU");
    expect(env.API_URL).toBe("http://localhost:4000");
  });

  it("parses target markets from env", () => {
    expect(parseTargetMarkets("AU,NZ")).toEqual(["AU", "NZ"]);
  });

  it("builds active market configs", () => {
    const markets = getActiveMarkets({ TARGET_MARKETS: "AU,NZ" });
    expect(markets.map((entry) => entry.code)).toEqual(["AU", "NZ"]);
  });

  it("builds public runtime config", () => {
    const config = buildPublicRuntimeConfig({ DEFAULT_MARKET: "AU" });
    expect(config.defaultMarket.currency).toBe("AUD");
  });

  it("returns market metadata", () => {
    expect(getMarketConfig("AU").locale).toBe("en-AU");
  });
});
