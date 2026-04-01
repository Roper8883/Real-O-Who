import type { FastifyInstance } from "fastify";
import { z } from "zod";
import { can, signInSchema, signUpSchema } from "@homeowner/auth";
import { buildPublicRuntimeConfig, getActiveMarkets, getMarketConfig, loadEnv } from "@homeowner/config";
import { store } from "../lib/store";

export async function registerRoutes(app: FastifyInstance) {
  const env = loadEnv();
  const publicConfig = buildPublicRuntimeConfig();

  app.get("/health", async () => ({
    status: "ok",
    service: "homeowner-api",
    market: publicConfig.defaultMarket.code,
    timestamp: new Date().toISOString(),
  }));

  app.get("/ready", async () => ({
    status: "ready",
    dependencies: {
      databaseUrlConfigured: Boolean(env.DATABASE_URL),
      redisUrlConfigured: Boolean(env.REDIS_URL),
      storageEndpointConfigured: Boolean(env.S3_ENDPOINT),
    },
    markets: getActiveMarkets().map((market) => market.code),
  }));

  app.get("/config/public", async () => ({
    item: publicConfig,
  }));

  app.get("/markets", async () => ({
    items: getActiveMarkets(),
  }));

  app.get("/markets/:market", async (request, reply) => {
    const params = z.object({ market: z.enum(["AU", "NZ", "UK", "US"]) }).parse(request.params);

    try {
      return {
        item: getMarketConfig(params.market),
      };
    } catch {
      reply.code(404);
      return { message: "Market not found" };
    }
  });

  app.post("/auth/signup", async (request, reply) => {
    const body = signUpSchema.parse(request.body);
    const user = store.createUser({
      displayName: body.displayName,
      email: body.email,
      role: body.role,
    });

    reply.code(201);
    return {
      user,
      message: "Account created. Email verification pending.",
    };
  });

  app.post("/auth/magic-link/request", async (request) => {
    const body = z
      .object({
        email: z.string().email(),
        redirectTo: z.string().url().optional(),
      })
      .parse(request.body);

    return {
      message: "Magic link requested.",
      email: body.email,
      redirectTo: body.redirectTo ?? `${publicConfig.webUrl}/auth/callback`,
    };
  });

  app.post("/auth/verify-email", async (request) => {
    const body = z
      .object({
        token: z.string().min(6),
      })
      .parse(request.body);

    return {
      verified: true,
      tokenPreview: body.token.slice(0, 4),
    };
  });

  app.get("/auth/social/providers", async () => ({
    items: ["google", "apple"],
  }));

  app.post("/auth/signin", async (request) => {
    const body = signInSchema.parse(request.body);

    return {
      email: body.email,
      session: {
        accessToken: "demo-access-token",
        refreshToken: "demo-refresh-token",
      },
    };
  });

  app.get("/rules/:state", async (request) => {
    const params = z
      .object({
        state: z.enum(["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"]),
      })
      .parse(request.params);

    return {
      ruleSet: store.getRules(params.state),
    };
  });

  app.get("/listings", async (request) => {
    const query = z
      .object({
        query: z.string().optional(),
        state: z
          .enum(["NSW", "VIC", "QLD", "SA", "ACT", "NT", "WA", "TAS"])
          .optional(),
        minBedrooms: z.coerce.number().optional(),
        minPrice: z.coerce.number().optional(),
        maxPrice: z.coerce.number().optional(),
        includeUnderOffer: z.coerce.boolean().optional(),
        sellerVerified: z.coerce.boolean().optional(),
        pool: z.coerce.boolean().optional(),
        sort: z
          .enum(["relevance", "newest", "price_asc", "price_desc", "land_desc"])
          .optional(),
      })
      .parse(request.query);

    return {
      items: store.listListings(query),
      total: store.listListings(query).length,
    };
  });

  app.get("/listings/:slug", async (request, reply) => {
    const params = z.object({ slug: z.string() }).parse(request.params);
    const listing = store.getListingBySlug(params.slug);

    if (!listing) {
      reply.code(404);
      return { message: "Listing not found" };
    }

    return {
      item: listing,
      warnings: store.getOfferWarnings(listing.address.state),
    };
  });

  app.post("/listings", async (request, reply) => {
    const body = z
      .object({
        title: z.string(),
        sellerId: z.string(),
        sellerName: z.string(),
        slug: z.string().optional(),
      })
      .parse(request.body);

    const listing = store.createDraftListing(body);
    reply.code(201);
    return { item: listing };
  });

  app.get("/saved-properties", async () => ({
    items: store.listSavedProperties(),
  }));

  app.post("/saved-properties", async (request, reply) => {
    const body = z
      .object({
        listingId: z.string(),
        collection: z.string(),
        note: z.string().optional(),
        tags: z.array(z.string()),
        status: z.enum(["saved", "viewed", "inspected", "offered"]),
      })
      .parse(request.body);

    const savedProperty = store.saveProperty(body);
    reply.code(201);
    return { item: savedProperty };
  });

  app.get("/conversations", async () => ({
    items: store.listConversations(),
  }));

  app.post("/conversations/:conversationId/messages", async (request) => {
    const params = z.object({ conversationId: z.string() }).parse(request.params);
    const body = z
      .object({
        senderId: z.string(),
        body: z.string().min(1),
      })
      .parse(request.body);

    return {
      item: store.appendMessage(params.conversationId, body.senderId, body.body),
    };
  });

  app.get("/inspection-bookings", async () => ({
    items: store.listInspectionBookings(),
  }));

  app.post("/inspection-bookings", async (request, reply) => {
    const body = z
      .object({
        listingId: z.string(),
        slotId: z.string(),
        buyerId: z.string(),
        attendeeCount: z.number().min(1),
        note: z.string().optional(),
      })
      .parse(request.body);

    const booking = store.createInspectionBooking(body);
    reply.code(201);
    return { item: booking };
  });

  app.get("/offers", async () => ({
    items: store.listOfferThreads(),
  }));

  app.post("/offers", async (request, reply) => {
    const body = z
      .object({
        listingId: z.string(),
        buyerId: z.string(),
        sellerId: z.string(),
        status: z.enum([
          "draft",
          "submitted",
          "under_review",
          "countered",
          "accepted",
          "accepted_in_principle",
          "declined",
          "rejected",
          "expired",
          "contract_requested",
          "withdrawn",
          "under_contract",
          "completed",
        ]),
        disclaimers: z.array(z.string()),
        versions: z.array(
          z.object({
            id: z.string(),
            amount: z.number(),
            depositIntent: z.number(),
            settlementDays: z.number(),
            subjectToFinance: z.boolean(),
            subjectToBuildingInspection: z.boolean(),
            subjectToPestInspection: z.boolean(),
            subjectToSaleOfHome: z.boolean(),
            requestedInclusions: z.array(z.string()),
            acknowledgedExclusions: z.array(z.string()),
            expiresAt: z.string(),
            message: z.string(),
            evidenceUploaded: z.boolean(),
            legalRepresentativeName: z.string().optional(),
            createdAt: z.string(),
          }),
        ),
      })
      .parse(request.body);

    const thread = store.createOfferThread(body);
    reply.code(201);
    return { item: thread };
  });

  app.post("/offers/:offerThreadId/counter", async (request) => {
    const params = z.object({ offerThreadId: z.string() }).parse(request.params);
    const body = z
      .object({
        id: z.string(),
        amount: z.number(),
        depositIntent: z.number(),
        settlementDays: z.number(),
        subjectToFinance: z.boolean(),
        subjectToBuildingInspection: z.boolean(),
        subjectToPestInspection: z.boolean(),
        subjectToSaleOfHome: z.boolean(),
        requestedInclusions: z.array(z.string()),
        acknowledgedExclusions: z.array(z.string()),
        expiresAt: z.string(),
        message: z.string(),
        evidenceUploaded: z.boolean(),
        legalRepresentativeName: z.string().optional(),
        createdAt: z.string(),
      })
      .parse(request.body);

    return {
      item: store.counterOffer(params.offerThreadId, body),
    };
  });

  app.get("/service-providers", async () => ({
    items: store.listServiceProviders(),
  }));

  app.get("/admin/metrics", async (request, reply) => {
    const role = z
      .object({
        role: z.enum([
          "guest",
          "buyer",
          "seller",
          "seller_buyer",
          "inspector",
          "admin",
          "support",
          "compliance",
        ]),
      })
      .parse(request.query);

    if (!can(role.role, "users:read") && !can(role.role, "listings:review")) {
      reply.code(403);
      return { message: "Forbidden" };
    }

    return {
      metrics: store.getAdminMetrics(),
    };
  });
}
