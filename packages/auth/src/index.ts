import bcrypt from "bcryptjs";
import type { UserRole } from "@homeowner/types";
import { z } from "zod";

const PASSWORD_MIN_LENGTH = 12;

export const signUpSchema = z.object({
  displayName: z.string().min(2).max(100),
  email: z.string().email(),
  password: z
    .string()
    .min(PASSWORD_MIN_LENGTH)
    .regex(/[A-Z]/, "Password must include an uppercase letter")
    .regex(/[a-z]/, "Password must include a lowercase letter")
    .regex(/[0-9]/, "Password must include a number"),
  role: z.enum(["buyer", "seller", "seller_buyer", "inspector"]),
});

export const signInSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

export const rolePermissions: Record<UserRole, string[]> = {
  guest: ["listings:read", "rules:read"],
  buyer: [
    "listings:read",
    "saved:create",
    "message:create",
    "inspection:book",
    "offer:create",
    "rules:read",
  ],
  seller: [
    "listings:read",
    "listings:create",
    "listings:update",
    "message:reply",
    "inspection:manage",
    "offer:manage",
    "rules:read",
  ],
  seller_buyer: [
    "listings:read",
    "listings:create",
    "listings:update",
    "saved:create",
    "message:create",
    "message:reply",
    "inspection:book",
    "inspection:manage",
    "offer:create",
    "offer:manage",
    "rules:read",
  ],
  inspector: ["provider:manage", "inspection:report", "rules:read"],
  admin: ["*"],
  support: ["users:read", "messages:moderate", "reports:review", "rules:read"],
  compliance: [
    "listings:review",
    "documents:review",
    "rules:read",
    "rules:update",
  ],
};

export function can(role: UserRole, permission: string): boolean {
  const permissions = rolePermissions[role] ?? [];
  return permissions.includes("*") || permissions.includes(permission);
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 12);
}

export async function verifyPassword(
  password: string,
  hash: string,
): Promise<boolean> {
  return bcrypt.compare(password, hash);
}
