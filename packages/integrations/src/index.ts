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
