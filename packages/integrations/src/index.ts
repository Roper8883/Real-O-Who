import { defaultFeatureFlags, loadEnv } from "@homeowner/config";

export interface MapsAdapter {
  provider: "mapbox" | "google" | "custom";
  geocode(address: string): Promise<{ latitude: number; longitude: number }>;
}

export interface EmailAdapter {
  provider: "resend" | "postmark" | "ses" | "console";
  send(input: { to: string; subject: string; html: string }): Promise<void>;
}

export interface SmsAdapter {
  provider: "twilio" | "messagebird" | "console";
  send(input: { to: string; body: string }): Promise<void>;
}

export interface StorageAdapter {
  provider: "s3" | "minio" | "local";
  signUpload(key: string): Promise<{ url: string; fields?: Record<string, string> }>;
  getSignedReadUrl(key: string): Promise<string>;
}

export interface FeatureFlagAdapter {
  provider: "launchdarkly" | "posthog" | "local";
  isEnabled(flag: string, context?: Record<string, string>): Promise<boolean>;
}

export interface IdentityVerificationAdapter {
  provider: "stub" | "veriff" | "persona";
  startSession(input: { userId: string; market: string }): Promise<{
    sessionId: string;
    status: "created" | "pending";
    redirectUrl?: string;
  }>;
}

export interface ValuationAdapter {
  provider: "stub" | "corelogic" | "domain";
  getEstimate(input: { address: string; bedrooms?: number; bathrooms?: number }): Promise<{
    estimateLow: number | null;
    estimateHigh: number | null;
    provenance: "estimated" | "licensed_provider" | "unavailable";
  }>;
}

export interface EsignAdapter {
  provider: "stub" | "docusign" | "hellosign";
  createEnvelope(input: {
    documentIds: string[];
    recipientEmails: string[];
    market: string;
  }): Promise<{ envelopeId: string; status: "draft" | "sent" }>;
}

export interface PaymentsAdapter {
  provider: "stripe" | "none";
  createCheckoutSession(input: {
    accountId: string;
    amount: number;
    currency: string;
    purpose: "listing_fee" | "boost" | "service_booking";
  }): Promise<{ sessionId: string; checkoutUrl: string }>;
}

export interface CalendarAdapter {
  provider: "stub" | "google" | "outlook";
  createBookingHold(input: {
    title: string;
    startsAt: string;
    endsAt: string;
    participantEmails: string[];
  }): Promise<{ externalId: string }>;
}

export interface ProviderRegistry {
  maps: MapsAdapter;
  email: EmailAdapter;
  sms: SmsAdapter;
  storage: StorageAdapter;
  featureFlags: FeatureFlagAdapter;
  identityVerification: IdentityVerificationAdapter;
  valuation: ValuationAdapter;
  esign: EsignAdapter;
  payments: PaymentsAdapter;
  calendar: CalendarAdapter;
}

export function createConsoleEmailAdapter(): EmailAdapter {
  return {
    provider: "console",
    async send(input) {
      console.info("[email.send]", input);
    },
  };
}

export function createConsoleSmsAdapter(): SmsAdapter {
  return {
    provider: "console",
    async send(input) {
      console.info("[sms.send]", input);
    },
  };
}

export function createLocalStorageAdapter(): StorageAdapter {
  return {
    provider: "local",
    async signUpload(key) {
      return {
        url: `http://localhost:9000/upload/${key}`,
        fields: { key },
      };
    },
    async getSignedReadUrl(key) {
      return `http://localhost:9000/private/${key}?signature=dev`;
    },
  };
}

export function createLocalFeatureFlagAdapter(
  enabledFlags: string[] = defaultFeatureFlags,
): FeatureFlagAdapter {
  const enabled = new Set(enabledFlags);

  return {
    provider: "local",
    async isEnabled(flag) {
      return enabled.has(flag);
    },
  };
}

export function createStubIdentityVerificationAdapter(): IdentityVerificationAdapter {
  return {
    provider: "stub",
    async startSession(input) {
      return {
        sessionId: `verify_${input.userId}`,
        status: "created",
        redirectUrl: `https://example.test/verify/${input.userId}`,
      };
    },
  };
}

export function createStubValuationAdapter(): ValuationAdapter {
  return {
    provider: "stub",
    async getEstimate() {
      return {
        estimateLow: null,
        estimateHigh: null,
        provenance: "unavailable",
      };
    },
  };
}

export function createStubEsignAdapter(): EsignAdapter {
  return {
    provider: "stub",
    async createEnvelope(input) {
      return {
        envelopeId: `env_${input.documentIds[0] ?? "draft"}`,
        status: "draft",
      };
    },
  };
}

export function createStubPaymentsAdapter(): PaymentsAdapter {
  return {
    provider: "none",
    async createCheckoutSession(input) {
      return {
        sessionId: `checkout_${input.accountId}`,
        checkoutUrl: `https://example.test/checkout/${input.accountId}`,
      };
    },
  };
}

export function createStubCalendarAdapter(): CalendarAdapter {
  return {
    provider: "stub",
    async createBookingHold(input) {
      return {
        externalId: `calendar_${input.startsAt}`,
      };
    },
  };
}

export function buildProviderRegistry(source: NodeJS.ProcessEnv = process.env): ProviderRegistry {
  const env = loadEnv(source);
  const localFlags = env.FEATURE_FLAGS_LOCAL
    ? env.FEATURE_FLAGS_LOCAL.split(",").map((entry) => entry.trim()).filter(Boolean)
    : defaultFeatureFlags;

  return {
    maps: {
      provider: env.MAP_PROVIDER,
      async geocode() {
        return { latitude: -27.4698, longitude: 153.0251 };
      },
    },
    email: createConsoleEmailAdapter(),
    sms: createConsoleSmsAdapter(),
    storage: createLocalStorageAdapter(),
    featureFlags: createLocalFeatureFlagAdapter(localFlags),
    identityVerification: createStubIdentityVerificationAdapter(),
    valuation: createStubValuationAdapter(),
    esign: createStubEsignAdapter(),
    payments: createStubPaymentsAdapter(),
    calendar: createStubCalendarAdapter(),
  };
}
