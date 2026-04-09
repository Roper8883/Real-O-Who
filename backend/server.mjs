import { createHash, randomBytes, randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import { createServer } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT ?? 8080);
const storagePath =
  process.env.REAL_O_WHO_DATA_FILE ??
  path.join(__dirname, "data", "dev-server.json");
const googlePlacesApiKey = String(process.env.GOOGLE_PLACES_API_KEY ?? "").trim();
const legalSearchRadiusMeters = 12000;
const legalWorkspaceInviteValidityMs = 1000 * 60 * 60 * 24 * 30;
const demoListingId = "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004";
const demoConversationId = "A0A2A8C9-83AF-479A-9AD6-4E0B28D64210";
const demoSaleId = "8F69115B-988B-4F30-A5F1-8E0CF6A41001";
const demoSharedPassword = "HouseDeal123!";
const demoBuyer = {
  id: "C8F18F9D-772E-4D62-8A88-0B9E23265002",
  name: "Noah Chen",
  role: "buyer",
  suburb: "New Farm, QLD",
  headline: "Focused on inner-city homes and direct owner conversations.",
  verificationNote: "Finance pre-approval uploaded",
  buyerStage: "preApproved",
  email: "noah@realowho.app"
};
const demoSeller = {
  id: "C8F18F9D-772E-4D62-8A88-0B9E23265004",
  name: "Mason Wright",
  role: "seller",
  suburb: "Wilston, QLD",
  headline: "Selling privately and managing inspections directly.",
  verificationNote: "Owner dashboard enabled",
  buyerStage: null,
  email: "mason@realowho.app"
};

const fallbackLegalProfessionals = [
  {
    id: "local-brisbane-conveyancing-group",
    name: "Brisbane Conveyancing Group",
    specialties: ["Conveyancing", "Contract review"],
    address: "Level 8, 123 Adelaide Street, Brisbane City QLD 4000",
    suburb: "Brisbane City",
    phoneNumber: "(07) 3123 4501",
    websiteURL: "https://www.google.com/search?q=Brisbane+Conveyancing+Group",
    mapsURL: "https://maps.google.com/?q=123+Adelaide+Street+Brisbane+City+QLD+4000",
    latitude: -27.4685,
    longitude: 153.0286,
    rating: 4.8,
    reviewCount: 61,
    source: "localFallback",
    searchSummary: "Handles private-sale contracts, cooling-off clauses, and settlement coordination."
  },
  {
    id: "local-rivercity-property-law",
    name: "Rivercity Property Law",
    specialties: ["Property solicitor", "Settlement support"],
    address: "42 Eagle Street, Brisbane City QLD 4000",
    suburb: "Brisbane City",
    phoneNumber: "(07) 3555 1180",
    websiteURL: "https://www.google.com/search?q=Rivercity+Property+Law",
    mapsURL: "https://maps.google.com/?q=42+Eagle+Street+Brisbane+City+QLD+4000",
    latitude: -27.4708,
    longitude: 153.0304,
    rating: 4.7,
    reviewCount: 49,
    source: "localFallback",
    searchSummary: "Property-law team with contract preparation and buyer-seller signing support."
  },
  {
    id: "local-west-end-settlement",
    name: "West End Settlement Co",
    specialties: ["Conveyancing", "Buyer support"],
    address: "19 Boundary Street, West End QLD 4101",
    suburb: "West End",
    phoneNumber: "(07) 3844 9082",
    websiteURL: "https://www.google.com/search?q=West+End+Settlement+Co",
    mapsURL: "https://maps.google.com/?q=19+Boundary+Street+West+End+QLD+4101",
    latitude: -27.4812,
    longitude: 153.0099,
    rating: 4.6,
    reviewCount: 34,
    source: "localFallback",
    searchSummary: "Popular with owner-sellers wanting fixed-fee contract work and settlement checklists."
  },
  {
    id: "local-bulimba-legal",
    name: "Bulimba Legal & Conveyancing",
    specialties: ["Property lawyer", "Contract negotiation"],
    address: "77 Oxford Street, Bulimba QLD 4171",
    suburb: "Bulimba",
    phoneNumber: "(07) 3399 4412",
    websiteURL: "https://www.google.com/search?q=Bulimba+Legal+%26+Conveyancing",
    mapsURL: "https://maps.google.com/?q=77+Oxford+Street+Bulimba+QLD+4171",
    latitude: -27.4523,
    longitude: 153.0577,
    rating: 4.8,
    reviewCount: 27,
    source: "localFallback",
    searchSummary: "Focuses on residential contracts, amendments, and pre-settlement issue resolution."
  },
  {
    id: "local-logan-private-sale-law",
    name: "Logan Private Sale Law",
    specialties: ["Solicitor", "Private sale paperwork"],
    address: "3 Wembley Road, Logan Central QLD 4114",
    suburb: "Logan Central",
    phoneNumber: "(07) 3290 7750",
    websiteURL: "https://www.google.com/search?q=Logan+Private+Sale+Law",
    mapsURL: "https://maps.google.com/?q=3+Wembley+Road+Logan+Central+QLD+4114",
    latitude: -27.6394,
    longitude: 153.1093,
    rating: 4.5,
    reviewCount: 18,
    source: "localFallback",
    searchSummary: "Helps private buyers and sellers handle contract exchange and settlement scheduling."
  },
  {
    id: "local-gold-coast-conveyancing",
    name: "Gold Coast Conveyancing Studio",
    specialties: ["Conveyancing", "e-signing support"],
    address: "9 Short Street, Southport QLD 4215",
    suburb: "Southport",
    phoneNumber: "(07) 5528 4100",
    websiteURL: "https://www.google.com/search?q=Gold+Coast+Conveyancing+Studio",
    mapsURL: "https://maps.google.com/?q=9+Short+Street+Southport+QLD+4215",
    latitude: -27.9682,
    longitude: 153.4086,
    rating: 4.7,
    reviewCount: 39,
    source: "localFallback",
    searchSummary: "Supports contract review, disclosure questions, and settlement on South East Queensland sales."
  }
];

const defaultState = {
  users: [],
  authAccounts: [],
  conversations: [],
  listings: [],
  marketplaceStateByUser: {},
  taskSnapshotStateByViewer: {},
  salesByListing: {}
};

let state = await loadState();

const server = createServer(async (request, response) => {
  applyCors(response);

  if (request.method === "OPTIONS") {
    response.writeHead(204);
    response.end();
    return;
  }

  const url = new URL(request.url ?? "/", `http://${request.headers.host ?? "localhost"}`);

  try {
    if (request.method === "GET" && url.pathname === "/health") {
      return json(response, 200, {
        ok: true,
        mode: "local-dev",
        users: state.users.length,
        conversations: state.conversations.length,
        listings: state.listings.length,
        sales: Object.keys(state.salesByListing).length
      });
    }

    if (request.method === "POST" && url.pathname === "/v1/auth/sign-up") {
      const body = await readJson(request);
      return handleSignUp(body, response);
    }

    if (request.method === "POST" && url.pathname === "/v1/auth/sign-in") {
      const body = await readJson(request);
      return handleSignIn(body, response);
    }

    if (
      request.method === "DELETE" &&
      url.pathname.startsWith("/v1/auth/account/")
    ) {
      const userId = url.pathname.split("/").pop();
      return handleDeleteAccount(userId, response);
    }

    if (request.method === "GET" && url.pathname === "/v1/conversations") {
      const userId = url.searchParams.get("userId");
      if (!userId) {
        return json(response, 400, { error: "Missing userId query parameter." });
      }

      return json(response, 200, {
        conversations: state.conversations.filter((thread) =>
          thread.participantIds.includes(userId)
        )
      });
    }

    if (
      request.method === "PUT" &&
      url.pathname.startsWith("/v1/conversations/")
    ) {
      const conversationId = url.pathname.split("/").pop();
      const body = await readJson(request);
      return handleConversationUpsert(conversationId, body, response);
    }

    if (
      request.method === "GET" &&
      url.pathname.startsWith("/v1/marketplace-state/")
    ) {
      const userId = url.pathname.split("/").pop();
      return handleMarketplaceStateFetch(userId, response);
    }

    if (
      request.method === "PUT" &&
      url.pathname.startsWith("/v1/marketplace-state/")
    ) {
      const userId = url.pathname.split("/").pop();
      const body = await readJson(request);
      return handleMarketplaceStateUpsert(userId, body, response);
    }

    if (
      request.method === "GET" &&
      url.pathname.startsWith("/v1/task-snapshot-state/")
    ) {
      const viewerId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
      return handleTaskSnapshotStateFetch(viewerId, response);
    }

    if (
      request.method === "PUT" &&
      url.pathname.startsWith("/v1/task-snapshot-state/")
    ) {
      const viewerId = decodeURIComponent(url.pathname.split("/").pop() ?? "");
      const body = await readJson(request);
      return handleTaskSnapshotStateUpsert(viewerId, body, response);
    }

    if (request.method === "GET" && url.pathname === "/v1/listings") {
      return json(response, 200, {
        listings: sortListings(state.listings)
      });
    }

    if (request.method === "GET" && url.pathname.startsWith("/v1/listings/")) {
      const listingId = url.pathname.split("/").pop();
      return handleListingFetch(listingId, response);
    }

    if (request.method === "PUT" && url.pathname.startsWith("/v1/listings/")) {
      const listingId = url.pathname.split("/").pop();
      const body = await readJson(request);
      return handleListingUpsert(listingId, body, response);
    }

    if (request.method === "GET" && url.pathname === "/v1/legal-professionals/search") {
      return handleLegalProfessionalSearch(url, response);
    }

    if (request.method === "GET" && url.pathname.startsWith("/v1/legal-workspace/")) {
      const inviteCode = decodeURIComponent(url.pathname.split("/").pop() ?? "");
      return handleLegalWorkspaceFetch(inviteCode, response);
    }

    if (request.method === "GET" && url.pathname === "/v1/sales") {
      const userId = url.searchParams.get("userId");
      return handleSalesFeedFetch(userId, response);
    }

    if (request.method === "GET" && url.pathname.startsWith("/v1/sales/by-listing/")) {
      const listingId = url.pathname.split("/").pop();
      return handleSaleFetch(listingId, response);
    }

    if (request.method === "PUT" && url.pathname.startsWith("/v1/sales/by-listing/")) {
      const listingId = url.pathname.split("/").pop();
      const body = await readJson(request);
      return handleSaleUpsert(listingId, body, response);
    }

    return json(response, 404, { error: "Route not found." });
  } catch (error) {
    return json(response, 500, {
      error: error instanceof Error ? error.message : "Unknown server error."
    });
  }
});

server.listen(port, () => {
  console.log(`Real O Who backend listening on http://127.0.0.1:${port}`);
});

async function handleSignUp(body, response) {
  const name = String(body?.name ?? "").trim();
  const email = normalizeEmail(body?.email);
  const password = String(body?.password ?? "");
  const role = body?.role === "buyer" ? "buyer" : body?.role === "seller" ? "seller" : null;
  const suburb = String(body?.suburb ?? "").trim();

  if (name.split(/\s+/).filter(Boolean).length < 2) {
    return json(response, 400, { error: "Enter your full name to continue." });
  }

  if (!isValidEmail(email)) {
    return json(response, 400, { error: "Enter a valid email address." });
  }

  if (suburb.length < 2) {
    return json(response, 400, { error: "Enter the suburb you live in or want to search." });
  }

  if (password.length < 8) {
    return json(response, 400, { error: "Use a password with at least 8 characters." });
  }

  if (!role) {
    return json(response, 400, { error: "Choose whether this account is a buyer or seller." });
  }

  if (state.authAccounts.some((account) => account.email === email)) {
    return json(response, 409, { error: "That email is already in use on this backend." });
  }

  const timestamp = new Date().toISOString();
  const user = {
    id: randomUUID(),
    name,
    role,
    suburb,
    headline:
      role === "seller"
        ? "Selling privately and keeping more of the final sale."
        : "Looking to buy directly from owners without agent friction.",
    verificationNote:
      role === "seller"
        ? "Private seller account created on the Real O Who backend"
        : "Buyer account created on the Real O Who backend",
    buyerStage: role === "buyer" ? "browsing" : null,
    createdAt: timestamp
  };

  const salt = randomBytes(16);
  const account = {
    id: randomUUID(),
    userId: user.id,
    email,
    passwordSaltBase64: salt.toString("base64"),
    passwordHashBase64: hashPassword(password, salt),
    createdAt: timestamp,
    lastSignedInAt: timestamp
  };

  state = {
    ...state,
    users: [user, ...state.users],
    authAccounts: [account, ...state.authAccounts]
  };
  await saveState(state);

  return json(response, 201, { user, account });
}

async function handleSignIn(body, response) {
  const email = normalizeEmail(body?.email);
  const password = String(body?.password ?? "");

  if (!isValidEmail(email)) {
    return json(response, 400, { error: "Enter a valid email address." });
  }

  const accountIndex = state.authAccounts.findIndex((account) => account.email === email);
  if (accountIndex === -1) {
    return json(response, 404, { error: "No backend account was found for that email yet." });
  }

  const account = state.authAccounts[accountIndex];
  const salt = Buffer.from(account.passwordSaltBase64, "base64");
  const hashed = hashPassword(password, salt);
  if (hashed !== account.passwordHashBase64) {
    return json(response, 401, { error: "That password does not match this backend account." });
  }

  const user = state.users.find((item) => item.id === account.userId);
  if (!user) {
    return json(response, 500, { error: "That account is missing its user profile." });
  }

  const updatedAccount = {
    ...account,
    lastSignedInAt: new Date().toISOString()
  };
  const authAccounts = [...state.authAccounts];
  authAccounts[accountIndex] = updatedAccount;
  state = { ...state, authAccounts };
  await saveState(state);

  return json(response, 200, { user, account: updatedAccount });
}

async function handleDeleteAccount(userId, response) {
  if (!userId || typeof userId !== "string") {
    return json(response, 400, { error: "User id is required." });
  }

  const userExists = state.users.some((user) => user.id === userId);
  if (!userExists) {
    return json(response, 404, { error: "That account could not be found on this backend." });
  }

  const listingIdsOwnedByUser = new Set(
    state.listings
      .filter((listing) => listing.sellerID === userId)
      .map((listing) => listing.id)
  );

  const salesByListing = Object.fromEntries(
    Object.entries(state.salesByListing).filter(([listingId, sale]) => {
      if (listingIdsOwnedByUser.has(listingId)) {
        return false;
      }

      return sale?.buyerID !== userId && sale?.sellerID !== userId;
    })
  );

  const filteredListings = state.listings.filter((listing) => listing.sellerID !== userId);
  const reconciledListings = syncListingsWithSales(sortListings(filteredListings), salesByListing).listings;

  state = {
    ...state,
    users: state.users.filter((user) => user.id !== userId),
    authAccounts: state.authAccounts.filter((account) => account.userId !== userId),
    conversations: state.conversations.filter(
      (conversation) => !conversation.participantIds.includes(userId)
    ),
    listings: reconciledListings,
    marketplaceStateByUser: Object.fromEntries(
      Object.entries(state.marketplaceStateByUser).filter(([key]) => key !== userId)
    ),
    taskSnapshotStateByViewer: Object.fromEntries(
      Object.entries(state.taskSnapshotStateByViewer).filter(([key]) => key !== `user:${userId}`)
    ),
    salesByListing
  };
  await saveState(state);

  return json(response, 200, { ok: true });
}

async function handleConversationUpsert(conversationId, body, response) {
  if (!conversationId || typeof conversationId !== "string") {
    return json(response, 400, { error: "Conversation id is required." });
  }

  const participantIds = Array.isArray(body?.participantIds)
    ? body.participantIds.map((value) => String(value))
    : [];

  if (!body?.listingId || participantIds.length < 2 || !Array.isArray(body?.messages)) {
    return json(response, 400, { error: "Conversation payload is incomplete." });
  }

  const conversation = {
    id: conversationId,
    listingId: String(body.listingId),
    participantIds,
    encryptionLabel: String(body.encryptionLabel ?? "Synced dev transport"),
    updatedAt: String(body.updatedAt ?? new Date().toISOString()),
    messages: body.messages.map((message) => ({
      id: String(message.id ?? randomUUID()),
      senderId: String(message.senderId),
      sentAt: String(message.sentAt ?? new Date().toISOString()),
      body: String(message.body ?? ""),
      isSystem: Boolean(message.isSystem),
      saleTaskTarget: normalizeConversationSaleTaskTarget(message.saleTaskTarget)
    }))
  };

  const existingIndex = state.conversations.findIndex((item) => item.id === conversationId);
  const conversations = [...state.conversations];

  if (existingIndex == -1) {
    conversations.unshift(conversation);
  } else {
    conversations[existingIndex] = conversation;
  }

  state = { ...state, conversations: sortConversations(conversations) };
  await saveState(state);

  return json(response, 200, { conversation });
}

function emptyMarketplaceState(userId) {
  return {
    userID: String(userId ?? ""),
    favoriteListingIDs: [],
    savedSearches: []
  };
}

function emptyTaskSnapshotState(viewerId) {
  return {
    viewerID: String(viewerId ?? ""),
    seenUrgentSnapshotKeysByMessageID: {},
    seenUrgentSnapshotKeysByTaskID: {},
    seenUrgentSnapshotSeenAtByMessageID: {},
    seenUrgentSnapshotSeenAtByTaskID: {}
  };
}

async function handleMarketplaceStateFetch(userId, response) {
  if (!userId || typeof userId !== "string") {
    return json(response, 400, { error: "User id is required." });
  }

  return json(response, 200, {
    state: state.marketplaceStateByUser[userId] ?? emptyMarketplaceState(userId)
  });
}

async function handleMarketplaceStateUpsert(userId, body, response) {
  if (!userId || typeof userId !== "string") {
    return json(response, 400, { error: "User id is required." });
  }

  const rawState = body?.state ?? body;
  if (!rawState || typeof rawState !== "object") {
    return json(response, 400, { error: "Marketplace state payload is required." });
  }

  const normalizedState = normalizeMarketplaceStateRecord(rawState, userId);

  state = {
    ...state,
    marketplaceStateByUser: {
      ...state.marketplaceStateByUser,
      [userId]: normalizedState
    }
  };
  await saveState(state);

  return json(response, 200, { state: normalizedState });
}

async function handleTaskSnapshotStateFetch(viewerId, response) {
  if (!viewerId || typeof viewerId !== "string") {
    return json(response, 400, { error: "Viewer id is required." });
  }

  return json(response, 200, {
    state: state.taskSnapshotStateByViewer[viewerId] ?? emptyTaskSnapshotState(viewerId)
  });
}

async function handleTaskSnapshotStateUpsert(viewerId, body, response) {
  if (!viewerId || typeof viewerId !== "string") {
    return json(response, 400, { error: "Viewer id is required." });
  }

  const rawState = body?.state ?? body;
  if (!rawState || typeof rawState !== "object") {
    return json(response, 400, { error: "Task snapshot state payload is required." });
  }

  const normalizedState = normalizeTaskSnapshotStateRecord(rawState, viewerId);

  state = {
    ...state,
    taskSnapshotStateByViewer: {
      ...state.taskSnapshotStateByViewer,
      [viewerId]: normalizedState
    }
  };
  await saveState(state);

  return json(response, 200, { state: normalizedState });
}

async function handleLegalProfessionalSearch(url, response) {
  const latitude = Number(url.searchParams.get("lat"));
  const longitude = Number(url.searchParams.get("lng"));
  const suburb = String(url.searchParams.get("suburb") ?? "").trim();
  const stateCode = String(url.searchParams.get("state") ?? "").trim().toUpperCase();
  const postcode = String(url.searchParams.get("postcode") ?? "").trim();

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return json(response, 400, { error: "Listing latitude and longitude are required." });
  }

  let professionals = [];
  let mode = "fallback";

  if (googlePlacesApiKey) {
    try {
      professionals = await searchGoogleLegalProfessionals({
        latitude,
        longitude,
        suburb,
        stateCode,
        postcode
      });
      if (professionals.length > 0) {
        mode = "google_places";
      }
    } catch {
      professionals = [];
    }
  }

  if (professionals.length === 0) {
    professionals = fallbackLegalProfessionalsForArea({
      latitude,
      longitude,
      suburb,
      stateCode,
      postcode
    });
  }

  return json(response, 200, {
    professionals,
    mode,
    area: [suburb, stateCode, postcode].filter(Boolean).join(" ")
  });
}

async function handleLegalWorkspaceFetch(inviteCode, response) {
  const normalizedCode = String(inviteCode ?? "").trim().toUpperCase();
  if (!normalizedCode) {
    return json(response, 400, { error: "Invite code is required." });
  }

  const workspace = findWorkspaceByInviteCode(normalizedCode);
  if (!workspace) {
    return json(response, 404, { error: "That legal workspace invite could not be found." });
  }

  if (workspace.invite.revokedAt) {
    return json(response, 410, {
      error: "This legal workspace invite has been revoked. Ask the buyer or seller to send a fresh invite."
    });
  }

  if (isSaleWorkspaceInviteExpired(workspace.invite)) {
    return json(response, 410, {
      error: "This legal workspace invite has expired. Ask the buyer or seller to send a fresh invite."
    });
  }

  const activatedWorkspace = await activateSaleWorkspaceInviteIfNeeded(normalizedCode, workspace);
  return json(response, 200, activatedWorkspace);
}

async function handleListingFetch(listingId, response) {
  if (!listingId || typeof listingId !== "string") {
    return json(response, 400, { error: "Listing id is required." });
  }

  return json(response, 200, {
    listing: state.listings.find((item) => item.id === listingId) ?? null
  });
}

async function handleListingUpsert(listingId, body, response) {
  if (!listingId || typeof listingId !== "string") {
    return json(response, 400, { error: "Listing id is required." });
  }

  const rawListing = body?.listing ?? body;
  if (!rawListing || typeof rawListing !== "object") {
    return json(response, 400, { error: "Listing payload is required." });
  }

  const normalizedListing = normalizeListingRecord(rawListing, listingId);
  const existingIndex = state.listings.findIndex((item) => item.id === listingId);
  const listings = [...state.listings];

  if (existingIndex === -1) {
    listings.unshift(normalizedListing);
  } else {
    listings[existingIndex] = normalizedListing;
  }

  state = {
    ...state,
    listings: syncListingsWithSales(sortListings(listings), state.salesByListing).listings
  };
  await saveState(state);

  return json(response, 200, { listing: normalizedListing });
}

async function handleSaleFetch(listingId, response) {
  if (!listingId || typeof listingId !== "string") {
    return json(response, 400, { error: "Listing id is required." });
  }

  return json(response, 200, {
    sale: state.salesByListing[listingId] ?? null
  });
}

async function handleSalesFeedFetch(userId, response) {
  const sales = sortSales(Object.values(state.salesByListing)).filter((sale) => {
    if (!userId) {
      return true;
    }

    return sale.buyerID === userId || sale.sellerID === userId;
  });

  return json(response, 200, { sales });
}

async function handleSaleUpsert(listingId, body, response) {
  if (!listingId || typeof listingId !== "string") {
    return json(response, 400, { error: "Listing id is required." });
  }

  const rawSale = body?.sale ?? body;
  if (!rawSale || typeof rawSale !== "object") {
    return json(response, 400, { error: "Sale payload is required." });
  }

  const normalizedSale = normalizeSaleRecord(rawSale, listingId);
  const salesByListing = {
    ...state.salesByListing,
    [listingId]: normalizedSale
  };
  const listings = [...state.listings];
  const listingIndex = listings.findIndex((item) => item.id === listingId);
  if (listingIndex !== -1) {
    listings[listingIndex] = {
      ...listings[listingIndex],
      status: listingStatusForSale(normalizedSale),
      updatedAt: new Date().toISOString()
    };
  }

  state = {
    ...state,
    listings: sortListings(listings),
    salesByListing
  };
  await saveState(state);

  return json(response, 200, { sale: normalizedSale });
}

function findWorkspaceByInviteCode(inviteCode) {
  for (const sale of Object.values(state.salesByListing)) {
    const invite = sale.invites.find(
      (candidate) => String(candidate.shareCode ?? "").trim().toUpperCase() === inviteCode
    );
    if (!invite) {
      continue;
    }

    const listing = state.listings.find((item) => item.id === sale.listingID) ?? null;
    return {
      listing,
      sale,
      invite
    };
  }

  return null;
}

async function activateSaleWorkspaceInviteIfNeeded(inviteCode, workspace) {
  if (workspace.invite.activatedAt) {
    return workspace;
  }

  const sale = state.salesByListing[workspace.sale.listingID];
  if (!sale) {
    return workspace;
  }

  const activatedAt = new Date().toISOString();
  const updatedInvites = sale.invites.map((candidate) => {
    if (String(candidate.shareCode ?? "").trim().toUpperCase() !== inviteCode) {
      return candidate;
    }

    return {
      ...candidate,
      activatedAt
    };
  });
  const updatedInvite = updatedInvites.find(
    (candidate) => String(candidate.shareCode ?? "").trim().toUpperCase() === inviteCode
  );
  if (!updatedInvite) {
    return workspace;
  }

  const openTitle = "Legal workspace opened";
  const openBody = `${updatedInvite.professionalName} opened the ${updatedInvite.role === "buyerRepresentative" ? "buyer legal rep access" : "seller legal rep access"} using invite code ${updatedInvite.shareCode}.`;

  const updatedSale = {
    ...sale,
    invites: updatedInvites,
    updates: [
      normalizeSaleUpdateMessage({
        createdAt: activatedAt,
        title: openTitle,
        body: openBody
      }),
      ...(sale.updates ?? [])
    ]
  };

  state = {
    ...state,
    salesByListing: {
      ...state.salesByListing,
      [sale.listingID]: updatedSale
    }
  };
  await saveState(state);

  return {
    listing: workspace.listing,
    sale: updatedSale,
    invite: updatedInvite
  };
}

function sortConversations(conversations) {
  return [...conversations].sort((left, right) => {
    return new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime();
  });
}

function sortListings(listings) {
  return [...listings].sort((left, right) => {
    return new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime();
  });
}

function sortSales(sales) {
  return [...sales].sort((left, right) => {
    return new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime();
  });
}

function syncListingsWithSales(listings, salesByListing) {
  let didChange = false;

  const syncedListings = listings.map((listing) => {
    const matchingSale = salesByListing[listing.id];
    if (!matchingSale) {
      return listing;
    }

    const expectedListingStatus = listingStatusForSale(matchingSale);
    if (expectedListingStatus === listing.status) {
      return listing;
    }

    didChange = true;
    return {
      ...listing,
      status: expectedListingStatus,
      updatedAt: new Date().toISOString()
    };
  });

  return {
    didChange,
    listings: syncedListings
  };
}

function normalizeListingRecord(rawListing, listingId) {
  if (!rawListing.title || !rawListing.address || !rawListing.sellerID) {
    throw new Error("Listing payload must include title, address, and sellerID.");
  }

  return {
    id: String(rawListing.id ?? listingId),
    title: String(rawListing.title ?? ""),
    headline: String(rawListing.headline ?? ""),
    summary: String(rawListing.summary ?? ""),
    propertyType: normalizeEnumValue(rawListing.propertyType, ["house", "apartment", "townhouse", "acreage", "land"], "house"),
    status: normalizeEnumValue(rawListing.status, ["active", "underOffer", "sold", "draft"], "active"),
    address: normalizePropertyAddress(rawListing.address),
    askingPrice: Number(rawListing.askingPrice ?? 0),
    bedrooms: Number(rawListing.bedrooms ?? 0),
    bathrooms: Number(rawListing.bathrooms ?? 0),
    parkingSpaces: Number(rawListing.parkingSpaces ?? 0),
    landSizeText: String(rawListing.landSizeText ?? ""),
    features: Array.isArray(rawListing.features) ? rawListing.features.map((value) => String(value)) : [],
    sellerID: String(rawListing.sellerID),
    inspectionSlots: Array.isArray(rawListing.inspectionSlots)
      ? rawListing.inspectionSlots.map(normalizeInspectionSlot)
      : [],
    marketPulse: normalizeMarketPulse(rawListing.marketPulse),
    comparableSales: Array.isArray(rawListing.comparableSales)
      ? rawListing.comparableSales.map(normalizeComparableSale)
      : [],
    palette: normalizeEnumValue(rawListing.palette, ["ocean", "sand", "gumleaf", "dusk"], "ocean"),
    latitude: Number(rawListing.latitude ?? 0),
    longitude: Number(rawListing.longitude ?? 0),
    isFeatured: Boolean(rawListing.isFeatured),
    publishedAt: String(rawListing.publishedAt ?? new Date().toISOString()),
    updatedAt: String(rawListing.updatedAt ?? new Date().toISOString())
  };
}

function normalizeMarketplaceStateRecord(rawState, userId) {
  const favoriteListingIDs = Array.isArray(rawState.favoriteListingIDs)
    ? Array.from(
        new Set(
          rawState.favoriteListingIDs
            .map((value) => String(value ?? "").trim())
            .filter(Boolean)
        )
      )
    : [];

  const savedSearches = Array.isArray(rawState.savedSearches)
    ? rawState.savedSearches.map(normalizeSavedSearch)
    : [];

  return {
    userID: String(rawState.userID ?? userId),
    favoriteListingIDs,
    savedSearches
  };
}

function normalizeTaskSnapshotStateRecord(rawState, viewerId) {
  const rawSeenSnapshotKeys =
    rawState?.seenUrgentSnapshotKeysByMessageID &&
    typeof rawState.seenUrgentSnapshotKeysByMessageID === "object"
      ? rawState.seenUrgentSnapshotKeysByMessageID
      : {};
  const rawSeenTaskSnapshotKeys =
    rawState?.seenUrgentSnapshotKeysByTaskID &&
    typeof rawState.seenUrgentSnapshotKeysByTaskID === "object"
      ? rawState.seenUrgentSnapshotKeysByTaskID
      : {};
  const rawSeenMessageTimestamps =
    rawState?.seenUrgentSnapshotSeenAtByMessageID &&
    typeof rawState.seenUrgentSnapshotSeenAtByMessageID === "object"
      ? rawState.seenUrgentSnapshotSeenAtByMessageID
      : {};
  const rawSeenTaskTimestamps =
    rawState?.seenUrgentSnapshotSeenAtByTaskID &&
    typeof rawState.seenUrgentSnapshotSeenAtByTaskID === "object"
      ? rawState.seenUrgentSnapshotSeenAtByTaskID
      : {};

  const seenUrgentSnapshotKeysByMessageID = Object.fromEntries(
    Object.entries(rawSeenSnapshotKeys)
      .map(([messageId, snapshotKey]) => [
        String(messageId ?? "").trim(),
        String(snapshotKey ?? "").trim()
      ])
      .filter(([messageId, snapshotKey]) => messageId && snapshotKey)
  );
  const seenUrgentSnapshotKeysByTaskID = Object.fromEntries(
    Object.entries(rawSeenTaskSnapshotKeys)
      .map(([taskId, snapshotKey]) => [
        String(taskId ?? "").trim(),
        String(snapshotKey ?? "").trim()
      ])
      .filter(([taskId, snapshotKey]) => taskId && snapshotKey)
  );
  const seenUrgentSnapshotSeenAtByMessageID = Object.fromEntries(
    Object.entries(rawSeenMessageTimestamps)
      .map(([messageId, seenAt]) => [
        String(messageId ?? "").trim(),
        Number(seenAt)
      ])
      .filter(([messageId, seenAt]) => messageId && Number.isFinite(seenAt) && seenAt > 0)
  );
  const seenUrgentSnapshotSeenAtByTaskID = Object.fromEntries(
    Object.entries(rawSeenTaskTimestamps)
      .map(([taskId, seenAt]) => [
        String(taskId ?? "").trim(),
        Number(seenAt)
      ])
      .filter(([taskId, seenAt]) => taskId && Number.isFinite(seenAt) && seenAt > 0)
  );

  return {
    viewerID: String(rawState.viewerID ?? viewerId),
    seenUrgentSnapshotKeysByMessageID,
    seenUrgentSnapshotKeysByTaskID,
    seenUrgentSnapshotSeenAtByMessageID,
    seenUrgentSnapshotSeenAtByTaskID
  };
}

function normalizeSavedSearch(rawSearch) {
  return {
    id: String(rawSearch?.id ?? randomUUID()),
    title: String(rawSearch?.title ?? "Saved search").trim() || "Saved search",
    suburb: String(rawSearch?.suburb ?? "").trim(),
    minimumPrice: Number(rawSearch?.minimumPrice ?? 0),
    maximumPrice: Number(rawSearch?.maximumPrice ?? 0),
    minimumBedrooms: Number(rawSearch?.minimumBedrooms ?? 0),
    propertyTypes: Array.isArray(rawSearch?.propertyTypes)
      ? rawSearch.propertyTypes.map((value) =>
          normalizeEnumValue(value, ["house", "apartment", "townhouse", "acreage", "land"], "house")
        )
      : [],
    alertsEnabled: Boolean(rawSearch?.alertsEnabled)
  };
}

function normalizePropertyAddress(address) {
  return {
    street: String(address?.street ?? ""),
    suburb: String(address?.suburb ?? ""),
    state: String(address?.state ?? ""),
    postcode: String(address?.postcode ?? "")
  };
}

function normalizeInspectionSlot(slot) {
  return {
    id: String(slot?.id ?? randomUUID()),
    startsAt: String(slot?.startsAt ?? new Date().toISOString()),
    endsAt: String(slot?.endsAt ?? new Date().toISOString()),
    note: String(slot?.note ?? "Private inspection")
  };
}

function normalizeComparableSale(sale) {
  return {
    id: String(sale?.id ?? randomUUID()),
    address: String(sale?.address ?? ""),
    soldPrice: Number(sale?.soldPrice ?? 0),
    soldAt: String(sale?.soldAt ?? new Date().toISOString()),
    bedrooms: Number(sale?.bedrooms ?? 0)
  };
}

function normalizeMarketPulse(pulse) {
  return {
    valueEstimateLow: Number(pulse?.valueEstimateLow ?? 0),
    valueEstimateHigh: Number(pulse?.valueEstimateHigh ?? 0),
    suburbMedian: Number(pulse?.suburbMedian ?? 0),
    buyerDemandScore: Number(pulse?.buyerDemandScore ?? 0),
    averageDaysOnMarket: Number(pulse?.averageDaysOnMarket ?? 0),
    schoolInsight: normalizeSchoolInsight(pulse?.schoolInsight)
  };
}

function normalizeSchoolInsight(schoolInsight) {
  return {
    catchmentName: String(schoolInsight?.catchmentName ?? "Local catchment"),
    walkMinutes: Number(schoolInsight?.walkMinutes ?? 0),
    score: Number(schoolInsight?.score ?? 0)
  };
}

function normalizeEnumValue(value, allowed, fallback) {
  const normalizedValue = String(value ?? fallback);
  return allowed.includes(normalizedValue) ? normalizedValue : fallback;
}

function normalizeSaleRecord(rawSale, listingId) {
  if (!rawSale.id || !rawSale.buyerID || !rawSale.sellerID) {
    throw new Error("Sale payload must include id, buyerID, and sellerID.");
  }

  const createdAt = String(rawSale.createdAt ?? new Date().toISOString());
  const buyerLegalSelection = normalizeLegalSelection(rawSale.buyerLegalSelection);
  const sellerLegalSelection = normalizeLegalSelection(rawSale.sellerLegalSelection);
  const invites = Array.isArray(rawSale.invites)
    ? rawSale.invites.map(normalizeSaleWorkspaceInvite)
    : [];
  const documents = Array.isArray(rawSale.documents)
    ? rawSale.documents.map(normalizeSaleDocument)
    : [];
  const updates = Array.isArray(rawSale.updates)
    ? rawSale.updates.map(normalizeSaleUpdateMessage)
    : [];

  let contractPacket = normalizeContractPacket(rawSale.contractPacket, listingId);
  if (!contractPacket && buyerLegalSelection && sellerLegalSelection) {
    contractPacket = {
      id: randomUUID(),
      generatedAt: new Date().toISOString(),
      listingID: listingId,
      offerID: String(rawSale.id),
      buyerID: String(rawSale.buyerID),
      sellerID: String(rawSale.sellerID),
      buyerRepresentative: buyerLegalSelection.professional,
      sellerRepresentative: sellerLegalSelection.professional,
      summary: `Contract packet prepared for $${Number(rawSale.amount ?? 0).toLocaleString("en-AU")}. Buyer legal representative: ${buyerLegalSelection.professional.name}. Seller legal representative: ${sellerLegalSelection.professional.name}. Next step: both parties review and sign through their chosen legal contacts.`,
      buyerSignedAt: null,
      sellerSignedAt: null
    };
  }

  return {
    id: String(rawSale.id),
    listingID: listingId,
    buyerID: String(rawSale.buyerID),
    sellerID: String(rawSale.sellerID),
    amount: Number(rawSale.amount ?? 0),
    conditions: String(rawSale.conditions ?? ""),
    createdAt,
    status: normalizeOfferStatus(rawSale.status),
    buyerLegalSelection,
    sellerLegalSelection,
    contractPacket,
    invites,
    documents,
    updates
  };
}

function normalizeOfferStatus(value) {
  return normalizeEnumValue(
    value,
    ["underOffer", "changesRequested", "countered", "accepted"],
    "underOffer"
  );
}

function listingStatusForSale(sale) {
  if (!sale) {
    return "active";
  }

  if (sale.contractPacket?.buyerSignedAt && sale.contractPacket?.sellerSignedAt) {
    return "sold";
  }

  switch (sale.status) {
    case "underOffer":
    case "changesRequested":
    case "countered":
    case "accepted":
    default:
      return "underOffer";
  }
}

function normalizeLegalSelection(selection) {
  if (!selection || typeof selection !== "object" || !selection.professional) {
    return null;
  }

  return {
    userID: String(selection.userID ?? ""),
    selectedAt: String(selection.selectedAt ?? new Date().toISOString()),
    professional: normalizeLegalProfessional(selection.professional)
  };
}

function normalizeContractPacket(packet, listingId) {
  if (!packet || typeof packet !== "object") {
    return null;
  }

  return {
    id: String(packet.id ?? randomUUID()),
    generatedAt: String(packet.generatedAt ?? new Date().toISOString()),
    listingID: String(packet.listingID ?? listingId),
    offerID: String(packet.offerID ?? ""),
    buyerID: String(packet.buyerID ?? ""),
    sellerID: String(packet.sellerID ?? ""),
    buyerRepresentative: normalizeLegalProfessional(packet.buyerRepresentative),
    sellerRepresentative: normalizeLegalProfessional(packet.sellerRepresentative),
    summary: String(packet.summary ?? ""),
    buyerSignedAt: packet.buyerSignedAt ? String(packet.buyerSignedAt) : null,
    sellerSignedAt: packet.sellerSignedAt ? String(packet.sellerSignedAt) : null
  };
}

function normalizeSaleDocument(document) {
  return {
    id: String(document?.id ?? randomUUID()),
    kind: normalizeEnumValue(
      document?.kind,
      [
        "contractPacketPDF",
        "councilRatesNoticePDF",
        "identityCheckPackPDF",
        "signedContractPDF",
        "settlementStatementPDF",
        "reviewedContractPDF",
        "settlementAdjustmentPDF"
      ],
      "contractPacketPDF"
    ),
    createdAt: String(document?.createdAt ?? new Date().toISOString()),
    fileName: String(document?.fileName ?? "sale-document.pdf"),
    summary: String(document?.summary ?? ""),
    uploadedByUserID: String(document?.uploadedByUserID ?? ""),
    uploadedByName: String(document?.uploadedByName ?? "Real O Who"),
    packetID: document?.packetID ? String(document.packetID) : null,
    mimeType: document?.mimeType ? String(document.mimeType) : null,
    attachmentBase64: document?.attachmentBase64 ? String(document.attachmentBase64) : null
  };
}

function normalizeSaleWorkspaceInvite(invite) {
  const createdAt = String(invite?.createdAt ?? new Date().toISOString());
  const createdAtTime = Date.parse(createdAt);
  const expiresAtFallback = new Date(
    (Number.isFinite(createdAtTime) ? createdAtTime : Date.now()) + legalWorkspaceInviteValidityMs
  ).toISOString();
  return {
    id: String(invite?.id ?? randomUUID()),
    role: normalizeEnumValue(
      invite?.role,
      ["buyerRepresentative", "sellerRepresentative"],
      "buyerRepresentative"
    ),
    createdAt,
    professionalName: String(invite?.professionalName ?? "Property law professional"),
    professionalSpecialty: String(invite?.professionalSpecialty ?? "Property law support"),
    shareCode: String(invite?.shareCode ?? ""),
    shareMessage: String(invite?.shareMessage ?? ""),
    expiresAt: String(invite?.expiresAt ?? expiresAtFallback),
    activatedAt: invite?.activatedAt ? String(invite.activatedAt) : null,
    revokedAt: invite?.revokedAt ? String(invite.revokedAt) : null,
    acknowledgedAt: invite?.acknowledgedAt ? String(invite.acknowledgedAt) : null,
    lastSharedAt: invite?.lastSharedAt ? String(invite.lastSharedAt) : null,
    shareCount: Math.max(Number.parseInt(String(invite?.shareCount ?? "0"), 10) || 0, 0),
    generatedByUserID: String(invite?.generatedByUserID ?? ""),
    generatedByName: String(invite?.generatedByName ?? "Real O Who")
  };
}

function isSaleWorkspaceInviteExpired(invite, referenceTimestamp = Date.now()) {
  const expiresAtTime = Date.parse(String(invite?.expiresAt ?? ""));
  if (!Number.isFinite(expiresAtTime)) {
    return false;
  }

  return expiresAtTime < referenceTimestamp;
}

function normalizeSaleUpdateMessage(update) {
  return {
    id: String(update?.id ?? randomUUID()),
    createdAt: String(update?.createdAt ?? new Date().toISOString()),
    title: String(update?.title ?? "Sale update"),
    body: String(update?.body ?? ""),
    kind: normalizeEnumValue(update?.kind, ["milestone", "reminder"], "milestone"),
    checklistItemID: update?.checklistItemID ? String(update.checklistItemID) : null
  };
}

function normalizeConversationSaleTaskTarget(target) {
  if (!target || typeof target !== "object") {
    return null;
  }

  if (!target.listingID || !target.offerID || !target.checklistItemID) {
    return null;
  }

  return {
    listingID: String(target.listingID),
    offerID: String(target.offerID),
    checklistItemID: String(target.checklistItemID)
  };
}

function normalizeLegalProfessional(professional) {
  return {
    id: String(professional?.id ?? randomUUID()),
    name: String(professional?.name ?? "Local property law professional"),
    specialties: Array.isArray(professional?.specialties)
      ? professional.specialties.map((value) => String(value))
      : [],
    address: String(professional?.address ?? ""),
    suburb: String(professional?.suburb ?? ""),
    phoneNumber: professional?.phoneNumber ? String(professional.phoneNumber) : null,
    websiteURL: professional?.websiteURL ? String(professional.websiteURL) : null,
    mapsURL: professional?.mapsURL ? String(professional.mapsURL) : null,
    latitude: Number(professional?.latitude ?? 0),
    longitude: Number(professional?.longitude ?? 0),
    rating: Number.isFinite(Number(professional?.rating)) ? Number(professional.rating) : null,
    reviewCount: Number.isFinite(Number(professional?.reviewCount)) ? Number(professional.reviewCount) : null,
    source: String(professional?.source ?? "localFallback"),
    searchSummary: String(professional?.searchSummary ?? "")
  };
}

async function searchGoogleLegalProfessionals({ latitude, longitude, suburb, stateCode, postcode }) {
  const areaLabel = [suburb, stateCode, postcode, "Australia"].filter(Boolean).join(" ");
  const searchPlans = [
    {
      textQuery: `conveyancer near ${areaLabel}`,
      specialties: ["Conveyancing", "Contract review"]
    },
    {
      textQuery: `property solicitor near ${areaLabel}`,
      specialties: ["Property solicitor", "Settlement support"]
    },
    {
      textQuery: `property lawyer near ${areaLabel}`,
      specialties: ["Property lawyer", "Private sale guidance"]
    }
  ];

  const searchResults = await Promise.allSettled(
    searchPlans.map((plan) => searchGooglePlacesText(plan, { latitude, longitude }))
  );

  const merged = new Map();

  for (const result of searchResults) {
    if (result.status !== "fulfilled") {
      continue;
    }

    for (const professional of result.value) {
      const existing = merged.get(professional.id);
      if (!existing) {
        merged.set(professional.id, professional);
        continue;
      }

      existing.specialties = Array.from(new Set([...existing.specialties, ...professional.specialties]));
      existing.searchSummary = professional.searchSummary ?? existing.searchSummary;
      existing.rating = Math.max(existing.rating ?? 0, professional.rating ?? 0) || existing.rating;
      existing.reviewCount = Math.max(existing.reviewCount ?? 0, professional.reviewCount ?? 0) || existing.reviewCount;
    }
  }

  return Array.from(merged.values())
    .sort((left, right) => {
      if ((right.rating ?? 0) === (left.rating ?? 0)) {
        return (right.reviewCount ?? 0) - (left.reviewCount ?? 0);
      }

      return (right.rating ?? 0) - (left.rating ?? 0);
    })
    .slice(0, 8);
}

async function searchGooglePlacesText(plan, { latitude, longitude }) {
  const fieldMask = [
    "places.id",
    "places.displayName",
    "places.formattedAddress",
    "places.location",
    "places.googleMapsUri",
    "places.websiteUri",
    "places.nationalPhoneNumber",
    "places.rating",
    "places.userRatingCount",
    "places.types"
  ].join(",");

  const googleResponse = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": googlePlacesApiKey,
      "X-Goog-FieldMask": fieldMask
    },
    body: JSON.stringify({
      textQuery: plan.textQuery,
      maxResultCount: 6,
      locationBias: {
        circle: {
          center: {
            latitude,
            longitude
          },
          radius: legalSearchRadiusMeters
        }
      }
    })
  });

  if (!googleResponse.ok) {
    const errorText = await googleResponse.text();
    throw new Error(`Google Places search failed: ${errorText}`);
  }

  const payload = await googleResponse.json();
  const places = Array.isArray(payload.places) ? payload.places : [];

  return places
    .filter((place) => {
      const types = Array.isArray(place.types) ? place.types : [];
      return types.length === 0 || types.includes("lawyer") || types.includes("point_of_interest");
    })
    .map((place) => mapGooglePlaceToLegalProfessional(place, plan.specialties));
}

function mapGooglePlaceToLegalProfessional(place, specialties) {
  const displayName =
    typeof place.displayName?.text === "string" && place.displayName.text.trim().length > 0
      ? place.displayName.text.trim()
      : "Local property law professional";
  const formattedAddress = String(place.formattedAddress ?? "").trim();
  const suburb = extractSuburbFromAddress(formattedAddress);
  const rating = Number(place.rating);
  const reviewCount = Number(place.userRatingCount);

  return {
    id: String(place.id),
    name: displayName,
    specialties,
    address: formattedAddress,
    suburb,
    phoneNumber: typeof place.nationalPhoneNumber === "string" ? place.nationalPhoneNumber : null,
    websiteURL: typeof place.websiteUri === "string" ? place.websiteUri : null,
    mapsURL: typeof place.googleMapsUri === "string" ? place.googleMapsUri : null,
    latitude: Number(place.location?.latitude ?? 0),
    longitude: Number(place.location?.longitude ?? 0),
    rating: Number.isFinite(rating) ? rating : null,
    reviewCount: Number.isFinite(reviewCount) ? reviewCount : null,
    source: "googlePlaces",
    searchSummary: `${specialties[0]} option surfaced near the property area through Google local listings.`
  };
}

function fallbackLegalProfessionalsForArea({ latitude, longitude, suburb, stateCode, postcode }) {
  const normalizedArea = `${suburb} ${stateCode} ${postcode}`.toLowerCase();

  return [...fallbackLegalProfessionals]
    .map((professional) => ({
      ...professional,
      distanceKm: distanceBetweenKm(
        latitude,
        longitude,
        professional.latitude,
        professional.longitude
      )
    }))
    .filter((professional) => {
      return (
        professional.distanceKm <= 120 ||
        professional.address.toLowerCase().includes(normalizedArea) ||
        professional.suburb.toLowerCase().includes(suburb.toLowerCase())
      );
    })
    .sort((left, right) => left.distanceKm - right.distanceKm)
    .slice(0, 8)
    .map(({ distanceKm, ...professional }) => ({
      ...professional,
      searchSummary: `${professional.searchSummary} Approx. ${distanceKm.toFixed(1)} km from the property.`
    }));
}

function extractSuburbFromAddress(address) {
  const parts = String(address)
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);

  if (parts.length < 2) {
    return "Local area";
  }

  return parts[parts.length - 2];
}

function distanceBetweenKm(lat1, lon1, lat2, lon2) {
  const earthRadiusKm = 6371;
  const dLat = degreesToRadians(lat2 - lat1);
  const dLon = degreesToRadians(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(degreesToRadians(lat1)) *
      Math.cos(degreesToRadians(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

function degreesToRadians(degrees) {
  return (degrees * Math.PI) / 180;
}

function normalizeEmail(value) {
  return String(value ?? "").trim().toLowerCase();
}

function isValidEmail(email) {
  return email.includes("@") && email.includes(".");
}

function hashPassword(password, saltBuffer) {
  return createHash("sha256")
    .update(Buffer.concat([saltBuffer, Buffer.from(password, "utf8")]))
    .digest("base64");
}

async function readJson(request) {
  const chunks = [];

  for await (const chunk of request) {
    chunks.push(chunk);
  }

  const payload = Buffer.concat(chunks).toString("utf8");
  return payload ? JSON.parse(payload) : {};
}

async function loadState() {
  try {
    await fs.mkdir(path.dirname(storagePath), { recursive: true });
    const raw = await fs.readFile(storagePath, "utf8");
    const parsed = JSON.parse(raw);
    const normalized = {
      users: Array.isArray(parsed.users) ? parsed.users : [],
      authAccounts: Array.isArray(parsed.authAccounts) ? parsed.authAccounts : [],
      conversations: Array.isArray(parsed.conversations) ? parsed.conversations : [],
      listings: Array.isArray(parsed.listings) ? parsed.listings : [],
      marketplaceStateByUser:
        parsed.marketplaceStateByUser && typeof parsed.marketplaceStateByUser === "object"
          ? Object.fromEntries(
              Object.entries(parsed.marketplaceStateByUser).map(([userId, marketplaceState]) => [
                userId,
                normalizeMarketplaceStateRecord(marketplaceState, userId)
              ])
            )
          : {},
      taskSnapshotStateByViewer:
        parsed.taskSnapshotStateByViewer && typeof parsed.taskSnapshotStateByViewer === "object"
          ? Object.fromEntries(
              Object.entries(parsed.taskSnapshotStateByViewer).map(([viewerId, taskSnapshotState]) => [
                viewerId,
                normalizeTaskSnapshotStateRecord(taskSnapshotState, viewerId)
              ])
            )
          : {},
      salesByListing:
        parsed.salesByListing && typeof parsed.salesByListing === "object"
          ? parsed.salesByListing
          : {}
    };
    const { state: seededState, didChange } = ensureDemoState(normalized);
    if (didChange) {
      await saveState(seededState);
    }
    return seededState;
  } catch {
    const seededState = ensureDemoState(structuredClone(defaultState)).state;
    await saveState(seededState);
    return seededState;
  }
}

async function saveState(nextState) {
  await fs.mkdir(path.dirname(storagePath), { recursive: true });
  const tempPath = `${storagePath}.tmp`;
  await fs.writeFile(tempPath, JSON.stringify(nextState, null, 2));
  await fs.rename(tempPath, storagePath);
}

function applyCors(response) {
  response.setHeader("Access-Control-Allow-Origin", "*");
  response.setHeader("Access-Control-Allow-Headers", "Content-Type");
  response.setHeader("Access-Control-Allow-Methods", "GET,POST,PUT,OPTIONS");
}

function json(response, statusCode, payload) {
  response.writeHead(statusCode, { "Content-Type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(payload));
}

function ensureDemoState(candidateState) {
  let didChange = false;
  const users = [...candidateState.users];
  const authAccounts = [...candidateState.authAccounts];
  const conversations = [...candidateState.conversations];
  const listings = [...candidateState.listings];
  const marketplaceStateByUser = { ...candidateState.marketplaceStateByUser };
  const taskSnapshotStateByViewer = { ...candidateState.taskSnapshotStateByViewer };
  const salesByListing = { ...candidateState.salesByListing };

  for (const user of [demoBuyer, demoSeller]) {
    if (!users.some((existing) => existing.id === user.id)) {
      users.unshift({
        id: user.id,
        name: user.name,
        role: user.role,
        suburb: user.suburb,
        headline: user.headline,
        verificationNote: user.verificationNote,
        buyerStage: user.buyerStage,
        createdAt: "2026-04-08T10:00:00Z"
      });
      didChange = true;
    }
  }

  const demoAccounts = [
    makeDemoAuthAccount(demoBuyer, "seed-demo-buyer1"),
    makeDemoAuthAccount(demoSeller, "seed-demo-seller")
  ];

  for (const account of demoAccounts) {
    if (
      !authAccounts.some(
        (existing) => existing.email === account.email || existing.userId === account.userId
      )
    ) {
      authAccounts.unshift(account);
      didChange = true;
    }
  }

  if (!conversations.some((thread) => thread.id === demoConversationId)) {
    conversations.unshift(makeDemoConversation());
    didChange = true;
  }

  const seededListings = makeSeedListings();
  for (const seededListing of seededListings) {
    if (!listings.some((listing) => listing.id === seededListing.id)) {
      listings.push(seededListing);
      didChange = true;
    }
  }

  const knownUserIds = new Set(users.map((user) => user.id));
  const existingDemoSale = salesByListing[demoListingId];
  if (
    !existingDemoSale ||
    !knownUserIds.has(String(existingDemoSale.buyerID ?? "")) ||
    !knownUserIds.has(String(existingDemoSale.sellerID ?? ""))
  ) {
    salesByListing[demoListingId] = makeDemoSale();
    didChange = true;
  } else if (!Array.isArray(existingDemoSale.updates) || existingDemoSale.updates.length === 0) {
    salesByListing[demoListingId] = {
      ...existingDemoSale,
      updates: makeDemoSale().updates
    };
    didChange = true;
  }

  const seededMarketplaceStates = makeSeedMarketplaceStates();
  for (const [userId, seededMarketplaceState] of Object.entries(seededMarketplaceStates)) {
    if (!marketplaceStateByUser[userId]) {
      marketplaceStateByUser[userId] = seededMarketplaceState;
      didChange = true;
    }
  }

  const reconciledListings = syncListingsWithSales(sortListings(listings), salesByListing);

  return {
    didChange: didChange || reconciledListings.didChange,
    state: {
      users,
      authAccounts,
      conversations: sortConversations(conversations),
      listings: reconciledListings.listings,
      marketplaceStateByUser,
      taskSnapshotStateByViewer,
      salesByListing
    }
  };
}

function makeDemoAuthAccount(user, saltLabel) {
  const salt = Buffer.from(saltLabel.padEnd(16, "0").slice(0, 16), "utf8");
  return {
    id: randomUUID(),
    userId: user.id,
    email: user.email,
    passwordSaltBase64: salt.toString("base64"),
    passwordHashBase64: hashPassword(demoSharedPassword, salt),
    createdAt: "2026-04-08T10:00:00Z",
    lastSignedInAt: "2026-04-08T10:00:00Z"
  };
}

function makeDemoConversation() {
  return {
    id: demoConversationId,
    listingId: demoListingId,
    participantIds: [demoBuyer.id, demoSeller.id],
    encryptionLabel: "Synced dev transport",
    updatedAt: "2026-04-08T10:15:00Z",
    messages: [
      {
        id: randomUUID(),
        senderId: demoSeller.id,
        sentAt: "2026-04-08T10:15:00Z",
        body: "Private chat is ready for the New Farm apartment. Ask about inspections, contract timing, or settlement here.",
        isSystem: true
      }
    ]
  };
}

function makeDemoSale() {
  return {
    id: demoSaleId,
    listingID: demoListingId,
    buyerID: demoBuyer.id,
    sellerID: demoSeller.id,
    amount: 855000,
    conditions: "Subject to finance approval and building and pest inspection.",
    createdAt: "2026-04-08T09:30:00Z",
    status: "underOffer",
    updates: [
      {
        id: randomUUID(),
        createdAt: "2026-04-08T09:30:00Z",
        title: "Offer received",
        body: "A private buyer has submitted an offer and both sides can now choose their legal representative."
      },
      {
        id: randomUUID(),
        createdAt: "2026-04-08T09:40:00Z",
        title: "Seller representative selected",
        body: "Mason Wright chose Rivercity Property Law to handle the property solicitor side of the sale."
      }
    ],
    buyerLegalSelection: null,
    sellerLegalSelection: {
      userID: demoSeller.id,
      selectedAt: "2026-04-08T09:40:00Z",
      professional: structuredClone(
        fallbackLegalProfessionals.find((professional) => professional.id === "local-rivercity-property-law") ??
          fallbackLegalProfessionals[1]
      )
    },
    contractPacket: null,
    invites: [],
    documents: []
  };
}

function makeSeedMarketplaceStates() {
  return {
    [demoBuyer.id]: {
      userID: demoBuyer.id,
      favoriteListingIDs: [
        "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004",
        "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002"
      ],
      savedSearches: [
        {
          id: "7A19AB1A-B78A-440D-8308-1F95FC891011",
          title: "Inner north buyer shortlist",
          suburb: "Wilston",
          minimumPrice: 900000,
          maximumPrice: 1400000,
          minimumBedrooms: 3,
          propertyTypes: ["house", "townhouse"],
          alertsEnabled: true
        },
        {
          id: "7A19AB1A-B78A-440D-8308-1F95FC891012",
          title: "Riverfront apartment watch",
          suburb: "New Farm",
          minimumPrice: 700000,
          maximumPrice: 980000,
          minimumBedrooms: 2,
          propertyTypes: ["apartment"],
          alertsEnabled: true
        }
      ]
    },
    [demoSeller.id]: {
      userID: demoSeller.id,
      favoriteListingIDs: [],
      savedSearches: []
    }
  };
}

function makeSeedListings() {
  return [
    {
      id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971001",
      title: "Renovated Queenslander with pool and studio",
      headline: "Privately listed family home with strong school catchment appeal.",
      summary: "A bright, elevated home with open-plan living, a detached studio, landscaped yard, and flexible private inspection windows for serious buyers.",
      propertyType: "house",
      status: "active",
      address: {
        street: "14 Roseberry Street",
        suburb: "Graceville",
        state: "QLD",
        postcode: "4075"
      },
      askingPrice: 1585000,
      bedrooms: 4,
      bathrooms: 2,
      parkingSpaces: 2,
      landSizeText: "607 sqm",
      features: ["Private pool", "Detached studio", "School catchment appeal", "Walk to rail", "Solar power"],
      sellerID: "C8F18F9D-772E-4D62-8A88-0B9E23265003",
      inspectionSlots: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972001",
          startsAt: "2026-04-10T23:30:00Z",
          endsAt: "2026-04-11T00:15:00Z",
          note: "Saturday private inspection"
        },
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972002",
          startsAt: "2026-04-11T07:30:00Z",
          endsAt: "2026-04-11T08:00:00Z",
          note: "After-work twilight viewing"
        }
      ],
      marketPulse: {
        valueEstimateLow: 1530000,
        valueEstimateHigh: 1610000,
        suburbMedian: 1490000,
        buyerDemandScore: 89,
        averageDaysOnMarket: 24,
        schoolInsight: {
          catchmentName: "Graceville State School",
          walkMinutes: 11,
          score: 91
        }
      },
      comparableSales: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973001",
          address: "22 Verney Road, Graceville",
          soldPrice: 1510000,
          soldAt: "2026-03-20T00:00:00Z",
          bedrooms: 4
        },
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973002",
          address: "7 Long Street East, Graceville",
          soldPrice: 1625000,
          soldAt: "2026-03-05T00:00:00Z",
          bedrooms: 4
        }
      ],
      palette: "ocean",
      latitude: -27.5232,
      longitude: 152.9817,
      isFeatured: true,
      publishedAt: "2026-04-06T08:30:00Z",
      updatedAt: "2026-04-08T07:10:00Z"
    },
    {
      id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971002",
      title: "Architect townhouse near Newmarket village",
      headline: "Turn-key private sale with curated finishes and quick offer path.",
      summary: "A low-maintenance inner-north townhouse with high ceilings, protected outdoor entertaining, and owner-managed inspections designed for efficient private sale.",
      propertyType: "townhouse",
      status: "active",
      address: {
        street: "5/32 Ashgrove Avenue",
        suburb: "Wilston",
        state: "QLD",
        postcode: "4051"
      },
      askingPrice: 1125000,
      bedrooms: 3,
      bathrooms: 2,
      parkingSpaces: 2,
      landSizeText: "192 sqm",
      features: ["Stone kitchen", "Courtyard", "Private garage", "Walk to cafes", "Low body corporate"],
      sellerID: "C8F18F9D-772E-4D62-8A88-0B9E23265004",
      inspectionSlots: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972003",
          startsAt: "2026-04-10T01:00:00Z",
          endsAt: "2026-04-10T01:30:00Z",
          note: "Open private inspection"
        }
      ],
      marketPulse: {
        valueEstimateLow: 1090000,
        valueEstimateHigh: 1155000,
        suburbMedian: 1070000,
        buyerDemandScore: 84,
        averageDaysOnMarket: 19,
        schoolInsight: {
          catchmentName: "Wilston State School",
          walkMinutes: 8,
          score: 88
        }
      },
      comparableSales: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973003",
          address: "3/14 Erin Street, Wilston",
          soldPrice: 1080000,
          soldAt: "2026-03-12T00:00:00Z",
          bedrooms: 3
        },
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973004",
          address: "8/41 Swan Terrace, Wilston",
          soldPrice: 1160000,
          soldAt: "2026-02-24T00:00:00Z",
          bedrooms: 3
        }
      ],
      palette: "sand",
      latitude: -27.4329,
      longitude: 153.0151,
      isFeatured: true,
      publishedAt: "2026-04-03T09:15:00Z",
      updatedAt: "2026-04-08T06:45:00Z"
    },
    {
      id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971003",
      title: "Leafy acreage retreat with secondary dwelling",
      headline: "Private acreage listing with strong multi-generational flexibility.",
      summary: "Set on usable land with a secondary dwelling and wide frontage, this private acreage sale is positioned for buyers seeking lifestyle space without losing access to the city.",
      propertyType: "acreage",
      status: "active",
      address: {
        street: "88 Cedar Creek Road",
        suburb: "Samford Valley",
        state: "QLD",
        postcode: "4520"
      },
      askingPrice: 1895000,
      bedrooms: 5,
      bathrooms: 3,
      parkingSpaces: 4,
      landSizeText: "1.4 ha",
      features: ["Secondary dwelling", "Rainwater tanks", "Horse-ready paddock", "Mountain outlook", "Large shed"],
      sellerID: "C8F18F9D-772E-4D62-8A88-0B9E23265003",
      inspectionSlots: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972004",
          startsAt: "2026-04-09T00:00:00Z",
          endsAt: "2026-04-09T01:00:00Z",
          note: "Booked acreage tour"
        }
      ],
      marketPulse: {
        valueEstimateLow: 1810000,
        valueEstimateHigh: 1920000,
        suburbMedian: 1760000,
        buyerDemandScore: 74,
        averageDaysOnMarket: 33,
        schoolInsight: {
          catchmentName: "Samford State School",
          walkMinutes: 14,
          score: 80
        }
      },
      comparableSales: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973005",
          address: "21 Wights Mountain Road, Samford Valley",
          soldPrice: 1840000,
          soldAt: "2026-03-08T00:00:00Z",
          bedrooms: 5
        }
      ],
      palette: "gumleaf",
      latitude: -27.3696,
      longitude: 152.8905,
      isFeatured: false,
      publishedAt: "2026-03-31T07:50:00Z",
      updatedAt: "2026-04-07T14:10:00Z"
    },
    {
      id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1971004",
      title: "Corner-block apartment with city skyline views",
      headline: "Investor-friendly layout with strong recent sales evidence.",
      summary: "An upper-level apartment with panoramic views, oversized balcony, and a private-seller workflow built for fast shortlist-to-offer conversion.",
      propertyType: "apartment",
      status: "active",
      address: {
        street: "17/85 Moray Street",
        suburb: "New Farm",
        state: "QLD",
        postcode: "4005"
      },
      askingPrice: 865000,
      bedrooms: 2,
      bathrooms: 2,
      parkingSpaces: 1,
      landSizeText: "108 sqm",
      features: ["City views", "Secure parking", "Lift access", "Balcony", "Walk to riverwalk"],
      sellerID: "C8F18F9D-772E-4D62-8A88-0B9E23265004",
      inspectionSlots: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1972005",
          startsAt: "2026-04-10T03:00:00Z",
          endsAt: "2026-04-10T03:25:00Z",
          note: "Mid-week private appointment"
        }
      ],
      marketPulse: {
        valueEstimateLow: 840000,
        valueEstimateHigh: 878000,
        suburbMedian: 912000,
        buyerDemandScore: 77,
        averageDaysOnMarket: 21,
        schoolInsight: {
          catchmentName: "New Farm State School",
          walkMinutes: 10,
          score: 85
        }
      },
      comparableSales: [
        {
          id: "DAA3A4D1-0FE6-4FD7-8A81-68D7E1973006",
          address: "12/71 Moray Street, New Farm",
          soldPrice: 855000,
          soldAt: "2026-03-23T00:00:00Z",
          bedrooms: 2
        }
      ],
      palette: "dusk",
      latitude: -27.4685,
      longitude: 153.0459,
      isFeatured: true,
      publishedAt: "2026-04-04T10:05:00Z",
      updatedAt: "2026-04-08T09:20:00Z"
    }
  ];
}
