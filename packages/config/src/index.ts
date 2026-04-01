import { z } from "zod";

export const marketSchema = z.enum(["AU", "NZ", "UK", "US"]);

export type MarketCode = z.infer<typeof marketSchema>;
export type CurrencyCode = "AUD" | "NZD" | "GBP" | "USD";

export const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  WEB_URL: z.string().url().default("http://localhost:3000"),
  ADMIN_URL: z.string().url().default("http://localhost:3001"),
  API_URL: z.string().url().default("http://localhost:4000"),
  DATABASE_URL: z.string().default("postgresql://postgres:postgres@localhost:5432/homeowner"),
  REDIS_URL: z.string().default("redis://localhost:6379"),
  S3_ENDPOINT: z.string().url().default("http://localhost:9000"),
  S3_REGION: z.string().default("ap-southeast-2"),
  S3_BUCKET: z.string().default("homeowner-dev"),
  S3_ACCESS_KEY: z.string().default("minio"),
  S3_SECRET_KEY: z.string().default("minio123"),
  JWT_ISSUER: z.string().min(1),
  JWT_AUDIENCE: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(1),
  JWT_REFRESH_SECRET: z.string().min(1),
  MAIL_FROM: z.string().email().default("no-reply@example.com"),
  MAP_PROVIDER: z.enum(["mapbox", "google", "custom"]).default("mapbox"),
  MAPBOX_ACCESS_TOKEN: z.string().default("replace-me"),
  FEATURE_FLAGS_PROVIDER: z.enum(["local", "launchdarkly", "posthog"]).default("local"),
  FEATURE_FLAGS_LOCAL: z.string().default(""),
  IDENTITY_PROVIDER: z.enum(["stub", "veriff", "persona"]).default("stub"),
  ESIGN_PROVIDER: z.enum(["stub", "docusign", "hellosign"]).default("stub"),
  VALUATION_PROVIDER: z.enum(["stub", "corelogic", "domain"]).default("stub"),
  PAYMENTS_PROVIDER: z.enum(["stripe", "none"]).default("stripe"),
  CALENDAR_PROVIDER: z.enum(["stub", "google", "outlook"]).default("stub"),
  SENTRY_DSN: z.string().optional(),
  TARGET_MARKETS: z.string().default("AU"),
  DEFAULT_MARKET: marketSchema.default("AU"),
  DEFAULT_CURRENCY: z.enum(["AUD", "NZD", "GBP", "USD"]).default("AUD"),
});

export interface MarketConfig {
  code: MarketCode;
  name: string;
  locale: string;
  currency: CurrencyCode;
  timezone: string;
  country: string;
  saleMethods: string[];
  defaultTaxesLabel: string;
  privacyRegionLabel: string;
}

export const marketCatalog: Record<MarketCode, MarketConfig> = {
  AU: {
    code: "AU",
    name: "Australia",
    locale: "en-AU",
    currency: "AUD",
    timezone: "Australia/Sydney",
    country: "Australia",
    saleMethods: ["private_treaty", "fixed_date_offers", "expression_of_interest"],
    defaultTaxesLabel: "GST and state-based duties handled outside platform fees",
    privacyRegionLabel: "Privacy Act 1988 (Cth) aligned",
  },
  NZ: {
    code: "NZ",
    name: "New Zealand",
    locale: "en-NZ",
    currency: "NZD",
    timezone: "Pacific/Auckland",
    country: "New Zealand",
    saleMethods: ["private_treaty", "deadline_sale"],
    defaultTaxesLabel: "GST handled according to local tax settings",
    privacyRegionLabel: "Privacy Act 2020 aligned",
  },
  UK: {
    code: "UK",
    name: "United Kingdom",
    locale: "en-GB",
    currency: "GBP",
    timezone: "Europe/London",
    country: "United Kingdom",
    saleMethods: ["private_treaty", "best_and_final"],
    defaultTaxesLabel: "VAT and regional taxes handled according to partner settings",
    privacyRegionLabel: "UK GDPR aligned",
  },
  US: {
    code: "US",
    name: "United States",
    locale: "en-US",
    currency: "USD",
    timezone: "America/New_York",
    country: "United States",
    saleMethods: ["private_treaty", "best_and_final"],
    defaultTaxesLabel: "Marketplace fees separated from escrow and closing funds",
    privacyRegionLabel: "CCPA/US state privacy aligned",
  },
};

const defaultEnvValues: z.input<typeof envSchema> = {
  NODE_ENV: "development",
  WEB_URL: "http://localhost:3000",
  ADMIN_URL: "http://localhost:3001",
  API_URL: "http://localhost:4000",
  DATABASE_URL: "postgresql://postgres:postgres@localhost:5432/homeowner",
  REDIS_URL: "redis://localhost:6379",
  S3_ENDPOINT: "http://localhost:9000",
  S3_REGION: "ap-southeast-2",
  S3_BUCKET: "homeowner-dev",
  S3_ACCESS_KEY: "minio",
  S3_SECRET_KEY: "minio123",
  JWT_ISSUER: "homeowner-platform",
  JWT_AUDIENCE: "homeowner-users",
  JWT_ACCESS_SECRET: "replace-me",
  JWT_REFRESH_SECRET: "replace-me-too",
  MAIL_FROM: "no-reply@example.com",
  MAP_PROVIDER: "mapbox",
  MAPBOX_ACCESS_TOKEN: "replace-me",
  FEATURE_FLAGS_PROVIDER: "local",
  FEATURE_FLAGS_LOCAL: "",
  IDENTITY_PROVIDER: "stub",
  ESIGN_PROVIDER: "stub",
  VALUATION_PROVIDER: "stub",
  PAYMENTS_PROVIDER: "stripe",
  CALENDAR_PROVIDER: "stub",
  TARGET_MARKETS: "AU",
  DEFAULT_MARKET: "AU",
  DEFAULT_CURRENCY: "AUD",
};

export function loadEnv(source: NodeJS.ProcessEnv = process.env) {
  return envSchema.parse({
    ...defaultEnvValues,
    ...source,
  });
}

export function parseTargetMarkets(input: string): MarketCode[] {
  return input
    .split(",")
    .map((entry) => entry.trim().toUpperCase())
    .filter((entry): entry is MarketCode => marketSchema.safeParse(entry).success);
}

export function getMarketConfig(market: MarketCode): MarketConfig {
  return marketCatalog[market];
}

export function getActiveMarkets(source: NodeJS.ProcessEnv = process.env): MarketConfig[] {
  const env = loadEnv(source);
  const targets = parseTargetMarkets(env.TARGET_MARKETS);
  const marketCodes = targets.length > 0 ? targets : [env.DEFAULT_MARKET];
  return marketCodes.map(getMarketConfig);
}

export function buildPublicRuntimeConfig(source: NodeJS.ProcessEnv = process.env) {
  const env = loadEnv(source);
  const defaultMarket = getMarketConfig(env.DEFAULT_MARKET);

  return {
    productName: "Homeowner",
    supportEmail: "support@homeowner.example",
    webUrl: env.WEB_URL,
    adminUrl: env.ADMIN_URL,
    apiUrl: env.API_URL,
    defaultMarket,
    activeMarkets: getActiveMarkets(source),
    featureFlagsProvider: env.FEATURE_FLAGS_PROVIDER,
  };
}

export const productConfig = {
  name: "Homeowner",
  tagline: "Australia-first private property sale platform",
  supportEmail: "support@homeowner.example",
  country: "Australia",
};

export const defaultFeatureFlags = [
  "listing-mode-coming-soon",
  "listing-mode-invite-only",
  "listing-mode-password-protected",
  "buyer-proof-of-funds-upload",
  "buyer-pre-approval-upload",
  "calendar-sync",
  "ai-description-drafts",
  "ai-photo-tagging",
  "provider-marketplace",
  "social-login",
  "magic-link-auth",
];
