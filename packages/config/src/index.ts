import { z } from "zod";

export const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  WEB_URL: z.string().url(),
  ADMIN_URL: z.string().url(),
  API_URL: z.string().url(),
  DATABASE_URL: z.string(),
  REDIS_URL: z.string(),
  JWT_ISSUER: z.string().min(1),
  JWT_AUDIENCE: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(1),
  JWT_REFRESH_SECRET: z.string().min(1),
});

export const productConfig = {
  name: "Homeowner",
  tagline: "Australia-first private property sale platform",
  supportEmail: "support@homeowner.example",
  country: "Australia",
};
