import type { UserProfile } from "@homeowner/types";
import { formatDistanceToNowStrict } from "date-fns";

export type NotificationEvent =
  | "signup_completed"
  | "seller_verification_started"
  | "listing_created"
  | "listing_published"
  | "property_saved"
  | "message_sent"
  | "inspection_requested"
  | "inspection_booked"
  | "report_requested"
  | "offer_submitted"
  | "offer_countered"
  | "offer_accepted_in_principle"
  | "contract_requested"
  | "listing_marked_under_offer"
  | "listing_marked_sold";

export function buildNotificationPreview(
  event: NotificationEvent,
  recipient: UserProfile,
  subject: string,
  timestamp: string,
): string {
  const age = formatDistanceToNowStrict(new Date(timestamp), { addSuffix: true });
  return `[${event}] ${subject} for ${recipient.displayName} (${age})`;
}
