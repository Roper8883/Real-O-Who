import {
  conversations,
  listings,
  offerThreads,
  sellers,
  serviceProviders,
} from "@homeowner/domain";
import { Prisma } from "@prisma/client";
import { prisma } from "../index";

async function main() {
  await prisma.readReceipt.deleteMany();
  await prisma.attachment.deleteMany();
  await prisma.message.deleteMany();
  await prisma.conversationParticipant.deleteMany();
  await prisma.conversation.deleteMany();
  await prisma.offerCondition.deleteMany();
  await prisma.offerEvidence.deleteMany();
  await prisma.offerVersion.deleteMany();
  await prisma.offerStatusEvent.deleteMany();
  await prisma.offerThread.deleteMany();
  await prisma.listingMedia.deleteMany();
  await prisma.propertyDocument.deleteMany();
  await prisma.inspectionSlot.deleteMany();
  await prisma.listing.deleteMany();
  await prisma.propertyAddress.deleteMany();
  await prisma.property.deleteMany();
  await prisma.serviceArea.deleteMany();
  await prisma.providerCredential.deleteMany();
  await prisma.serviceProvider.deleteMany();
  await prisma.user.deleteMany();

  for (const seller of sellers) {
    await prisma.user.create({
      data: {
        id: seller.id,
        email: seller.email,
        displayName: seller.displayName,
        phone: seller.phone,
        primaryRole: seller.role,
        roles: [seller.role],
        verifiedEmail: seller.verifiedEmail,
        verifiedPhone: seller.verifiedPhone,
        identityVerificationStatus: seller.identityVerificationStatus ?? "not_started",
        responseRate: seller.responseRate,
        averageResponseHours: seller.averageResponseHours,
      },
    });
  }

  for (const listing of listings) {
    const property = await prisma.property.create({
      data: {
        id: `${listing.id}-property`,
        title: listing.title,
        propertyType: listing.propertyType,
        state: listing.address.state,
        address: {
          create: {
            line1: listing.address.line1,
            suburb: listing.address.suburb,
            postcode: listing.address.postcode,
            state: listing.address.state,
            country: listing.address.country,
            councilArea: listing.address.councilArea,
            latitude: listing.address.coordinates.latitude,
            longitude: listing.address.coordinates.longitude,
          },
        },
      },
    });

    await prisma.listing.create({
      data: {
        id: listing.id,
        propertyId: property.id,
        sellerId: listing.sellerId,
        slug: listing.slug,
        status: listing.status,
        priceLabel: listing.priceLabel,
        askingPrice: listing.askingPrice,
        legalDisclosureStatus: listing.legalDisclosureStatus,
        publishedAt: new Date(listing.publishedAt),
        description: listing.description,
        ownerLoves: listing.ownerLoves,
        neighbourhoodHighlights: listing.neighbourhoodHighlights,
        settlementPreference: listing.settlementPreference,
        facts: listing.facts as unknown as Prisma.InputJsonValue,
        coverImage: listing.coverImage,
        media: {
          create: listing.heroMedia.map((media, index) => ({
            id: media.id,
            kind: media.kind,
            title: media.title,
            url: media.url,
            thumbnailUrl: media.thumbnailUrl,
            altText: media.altText,
            isCover: media.isCover ?? false,
            sortOrder: index,
          })),
        },
        documents: {
          create: listing.documents.map((document) => ({
            id: document.id,
            category: document.category,
            name: document.name,
            required: document.required,
            access: document.access,
            provenance: document.provenance,
            uploadedAt: document.uploadedAt ? new Date(document.uploadedAt) : undefined,
            expiresAt: document.expiresAt ? new Date(document.expiresAt) : undefined,
          })),
        },
        inspectionSlots: {
          create: listing.inspectionSlots.map((slot) => ({
            id: slot.id,
            type: slot.type,
            startAt: new Date(slot.startAt),
            endAt: new Date(slot.endAt),
            capacity: slot.capacity,
            bookedCount: slot.bookedCount,
            note: slot.note,
          })),
        },
      },
    });
  }

  for (const conversation of conversations) {
    await prisma.conversation.create({
      data: {
        id: conversation.id,
        listingId: conversation.listingId,
        lastMessagePreview: conversation.lastMessagePreview,
        unreadCount: conversation.unreadCount,
        flagged: conversation.flagged,
        participants: {
          create: conversation.participantIds.map((participantId) => ({
            userId: participantId,
          })),
        },
        messages: {
          create: conversation.messages.map((message) => ({
            id: message.id,
            senderId:
              message.senderId === "system" ? sellers[0].id : message.senderId,
            body: message.body,
            system: message.system ?? false,
            createdAt: new Date(message.sentAt),
          })),
        },
      },
    });
  }

  for (const offerThread of offerThreads) {
    await prisma.offerThread.create({
      data: {
        id: offerThread.id,
        listingId: offerThread.listingId,
        buyerId: offerThread.buyerId,
        sellerId: offerThread.sellerId,
        status: offerThread.status,
        disclaimers: offerThread.disclaimers,
        versions: {
          create: offerThread.versions.map((version) => ({
            id: version.id,
            amount: version.amount,
            depositIntent: version.depositIntent,
            settlementDays: version.settlementDays,
            subjectToFinance: version.subjectToFinance,
            subjectToBuildingInspection: version.subjectToBuildingInspection,
            subjectToPestInspection: version.subjectToPestInspection,
            subjectToSaleOfHome: version.subjectToSaleOfHome,
            requestedInclusions: version.requestedInclusions,
            acknowledgedExclusions: version.acknowledgedExclusions,
            expiresAt: new Date(version.expiresAt),
            message: version.message,
            evidenceUploaded: version.evidenceUploaded,
            legalRepresentativeName: version.legalRepresentativeName,
            createdAt: new Date(version.createdAt),
          })),
        },
      },
    });
  }

  for (const provider of serviceProviders) {
    await prisma.serviceProvider.create({
      data: {
        id: provider.id,
        businessName: provider.businessName,
        description: provider.description,
        serviceTypes: provider.serviceTypes,
        turnaroundHours: provider.turnaroundHours,
        insured: provider.insured,
        licenceVerified: provider.licenceVerified,
        serviceAreas: {
          create: provider.serviceArea.map((state) => ({
            state: state as never,
          })),
        },
      },
    });
  }

  console.log(
    `Seeded ${listings.length} listings, ${conversations.length} conversations, and ${offerThreads.length} offer threads.`,
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
