import QuickLook
import SwiftUI
import UIKit

struct PreparedSaleDocument: Identifiable {
    let id = UUID()
    let title: String
    let url: URL
}

enum SaleDocumentRenderer {
    static func render(
        document: SaleDocument,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile,
        fileManager: FileManager = .default
    ) throws -> PreparedSaleDocument {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("RealOWhoSaleDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let url = directory.appendingPathComponent(document.fileName)
        let data: Data
        if let attachmentBase64 = document.attachmentBase64,
           let attachmentData = Data(base64Encoded: attachmentBase64) {
            data = attachmentData
        } else {
            data = renderPDFData(
                document: document,
                listing: listing,
                offer: offer,
                buyer: buyer,
                seller: seller
            )
        }
        try data.write(to: url, options: [.atomic])

        return PreparedSaleDocument(
            title: document.title,
            url: url
        )
    }

    static func renderAttachment(
        title: String,
        fileName: String,
        attachmentBase64: String,
        fileManager: FileManager = .default
    ) throws -> PreparedSaleDocument {
        guard let data = Data(base64Encoded: attachmentBase64) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let directory = fileManager.temporaryDirectory.appendingPathComponent("RealOWhoSaleDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url, options: [.atomic])

        return PreparedSaleDocument(title: title, url: url)
    }

    static func renderPostSaleConciergeQuote(
        booking: PostSaleConciergeBooking,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile,
        fileManager: FileManager = .default
    ) throws -> PreparedSaleDocument {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("RealOWhoSaleDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let url = directory.appendingPathComponent(conciergeFileName(prefix: "quote", booking: booking, listing: listing))
        let title = "\(booking.serviceKind.title) quote summary"
        let data = renderConciergePDFData(
            title: title,
            createdAt: booking.bookedAt,
            listing: listing,
            offer: offer,
            buyer: buyer,
            seller: seller,
            booking: booking,
            supportingSection: """
            Quote details
            Provider: \(booking.provider.name)
            Service: \(booking.serviceKind.title)
            Scheduled for: \(DateFormatter.saleDocumentDate.string(from: booking.scheduledFor))
            Estimated cost: \(currencyLabel(for: booking.estimatedCost) ?? "Pending")
            Quote approved: \(formattedSignatureDate(booking.quoteApprovedAt))
            Invoice uploaded: \(formattedSignatureDate(booking.invoiceUploadedAt))
            """
        )
        try data.write(to: url, options: [.atomic])
        return PreparedSaleDocument(title: title, url: url)
    }

    static func renderPostSaleConciergeConfirmation(
        booking: PostSaleConciergeBooking,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile,
        fileManager: FileManager = .default
    ) throws -> PreparedSaleDocument {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("RealOWhoSaleDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let url = directory.appendingPathComponent(conciergeFileName(prefix: "completion", booking: booking, listing: listing))
        let title = "\(booking.serviceKind.title) completion proof"
        let data = renderConciergePDFData(
            title: title,
            createdAt: booking.completedAt ?? booking.bookedAt,
            listing: listing,
            offer: offer,
            buyer: buyer,
            seller: seller,
            booking: booking,
            supportingSection: """
            Completion record
            Provider: \(booking.provider.name)
            Service: \(booking.serviceKind.title)
            Scheduled for: \(DateFormatter.saleDocumentDate.string(from: booking.scheduledFor))
            Completed: \(formattedSignatureDate(booking.completedAt))
            Estimated cost: \(currencyLabel(for: booking.estimatedCost) ?? "Not recorded")
            Quote approved: \(formattedSignatureDate(booking.quoteApprovedAt))
            Invoice total: \(currencyLabel(for: booking.invoiceAmount) ?? "Not recorded")
            Paid total: \(currencyLabel(for: booking.paidAmount) ?? "Not recorded")
            Invoice on file: \(booking.hasInvoiceAttachment ? "Yes" : "No")
            Payment proof on file: \(booking.hasPaymentProof ? "Yes" : "No")
            """
        )
        try data.write(to: url, options: [.atomic])
        return PreparedSaleDocument(title: title, url: url)
    }

    static func renderPostSaleConciergeReceipt(
        booking: PostSaleConciergeBooking,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile,
        fileManager: FileManager = .default
    ) throws -> PreparedSaleDocument {
        let directory = fileManager.temporaryDirectory.appendingPathComponent("RealOWhoSaleDocuments", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)

        let url = directory.appendingPathComponent(conciergeFileName(prefix: "receipt", booking: booking, listing: listing))
        let title = "\(booking.serviceKind.title) service receipt"
        let providerHistorySection = conciergeProviderHistorySection(for: booking)
        let data = renderConciergePDFData(
            title: title,
            createdAt: booking.refundProcessedAt ?? booking.paymentConfirmedAt ?? booking.invoiceUploadedAt ?? booking.bookedAt,
            listing: listing,
            offer: offer,
            buyer: buyer,
            seller: seller,
            booking: booking,
            supportingSection: """
            Service receipt
            Provider: \(booking.provider.name)
            Service status: \(booking.status.title)
            Previous schedule: \(formattedSignatureDate(booking.previousScheduledFor))
            Rescheduled at: \(formattedSignatureDate(booking.lastRescheduledAt))
            Reschedule count: \(booking.rescheduleCountValue)
            Quote estimate: \(currencyLabel(for: booking.estimatedCost) ?? "Not recorded")
            Quote approved: \(formattedSignatureDate(booking.quoteApprovedAt))
            Provider confirmed: \(formattedSignatureDate(booking.providerConfirmedAt))
            Confirmed by: \(booking.providerConfirmedByName ?? "Not recorded")
            Confirmation note: \(booking.providerConfirmationNote ?? "Not recorded")
            Response SLA due: \(formattedSignatureDate(booking.responseDueAt))
            Reminder snoozed until: \(formattedSignatureDate(booking.reminderSnoozedUntil))
            Follow-up count: \(booking.followUpCountValue)
            Latest follow-up: \(formattedSignatureDate(booking.lastFollowUpAt))
            Follow-up by: \(booking.lastFollowUpByName ?? "Not recorded")
            Follow-up note: \(booking.lastFollowUpNote ?? "Not recorded")
            Invoice total: \(currencyLabel(for: booking.invoiceAmount) ?? "Not recorded")
            Invoice uploaded: \(formattedSignatureDate(booking.invoiceUploadedAt))
            Paid total: \(currencyLabel(for: booking.paidAmount) ?? "Not recorded")
            Payment confirmed: \(formattedSignatureDate(booking.paymentConfirmedAt))
            Provider issue: \(booking.issueKind?.title ?? "Not recorded")
            Issue logged: \(formattedSignatureDate(booking.issueLoggedAt))
            Issue note: \(booking.issueNote ?? "Not recorded")
            Issue resolved: \(formattedSignatureDate(booking.issueResolvedAt))
            Resolution note: \(booking.issueResolutionNote ?? "Not recorded")
            Refund total: \(currencyLabel(for: booking.refundAmount) ?? "Not recorded")
            Refund recorded: \(formattedSignatureDate(booking.refundProcessedAt))
            Cancelled: \(formattedSignatureDate(booking.cancelledAt))
            Cancellation reason: \(booking.cancellationReason ?? "Not recorded")
            Refund note: \(booking.refundNote ?? "Not recorded")
            \(providerHistorySection)
            """
        )
        try data.write(to: url, options: [.atomic])
        return PreparedSaleDocument(title: title, url: url)
    }

    private static func conciergeProviderHistorySection(for booking: PostSaleConciergeBooking) -> String {
        guard booking.hasProviderHistory else {
            return "Provider history: No previous providers recorded"
        }

        let lines = (booking.providerAuditHistory ?? []).prefix(4).map { entry in
            var line = "- \(entry.provider.name) • replaced \(formattedSignatureDate(entry.replacedAt))"
            if let providerConfirmedAt = entry.providerConfirmedAt {
                line += " • confirmed \(formattedSignatureDate(providerConfirmedAt))"
            }
            if let providerConfirmationNote = entry.providerConfirmationNote,
               providerConfirmationNote.isEmpty == false {
                line += " • note \(providerConfirmationNote)"
            }
            if let reminderSnoozedUntil = entry.reminderSnoozedUntil {
                line += " • snoozed until \(formattedSignatureDate(reminderSnoozedUntil))"
            }
            if let lastFollowUpAt = entry.lastFollowUpAt {
                line += " • follow-up \(formattedSignatureDate(lastFollowUpAt))"
            }
            if let followUpCount = entry.followUpCount, followUpCount > 0 {
                line += " • \(followUpCount) follow-up\(followUpCount == 1 ? "" : "s")"
            }
            if let lastFollowUpNote = entry.lastFollowUpNote,
               lastFollowUpNote.isEmpty == false {
                line += " • follow-up note \(lastFollowUpNote)"
            }
            if let issueKind = entry.issueKind {
                line += " • issue \(issueKind.title)"
            }
            if let refundAmount = entry.refundAmount {
                line += " • refund \(currencyLabel(for: refundAmount) ?? "Not recorded")"
            } else if let paidAmount = entry.paidAmount {
                line += " • paid \(currencyLabel(for: paidAmount) ?? "Not recorded")"
            } else if let invoiceAmount = entry.invoiceAmount {
                line += " • invoice \(currencyLabel(for: invoiceAmount) ?? "Not recorded")"
            } else if let estimatedCost = entry.estimatedCost {
                line += " • quote \(currencyLabel(for: estimatedCost) ?? "Not recorded")"
            }
            return line
        }

        let overflowLine: String
        if booking.providerHistoryCountValue > lines.count {
            overflowLine = "\n- \(booking.providerHistoryCountValue - lines.count) more previous provider records remain attached to this archive"
        } else {
            overflowLine = ""
        }

        return "Provider history\n" + lines.joined(separator: "\n") + overflowLine
    }

    private static func renderPDFData(
        document: SaleDocument,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]

            let formattedAmount = Currency.aud.string(from: NSNumber(value: offer.amount)) ?? "$\(offer.amount)"
            let buyerSignature = formattedSignatureDate(offer.contractPacket?.buyerSignedAt)
            let sellerSignature = formattedSignatureDate(offer.contractPacket?.sellerSignedAt)
            let documentDate = DateFormatter.saleDocumentDate.string(from: document.createdAt)
            let settlementCompleted = formattedSignatureDate(offer.settlementCompletedAt)

            var sections = [
                "\(document.title)\nGenerated \(documentDate)",
                """
                Property
                \(listing.title)
                \(listing.address.street), \(listing.address.suburb) \(listing.address.state) \(listing.address.postcode)
                """,
                """
                Deal terms
                Offer amount: \(formattedAmount)
                Current status: \(offer.listingStatus.title)
                Conditions: \(offer.conditions)
                """,
                """
                Buyer
                \(buyer.name)
                \(buyer.suburb)
                """,
                """
                Seller
                \(seller.name)
                \(seller.suburb)
                """,
                """
                Legal representatives
                Buyer: \(offer.contractPacket?.buyerRepresentative.name ?? "Pending")
                Seller: \(offer.contractPacket?.sellerRepresentative.name ?? "Pending")
                """,
                """
                Signatures
                Buyer sign-off: \(buyerSignature)
                Seller sign-off: \(sellerSignature)
                """,
                """
                Completion
                Settlement confirmed: \(settlementCompleted)
                """,
                """
                Document summary
                \(document.summary)
                """
            ]

            if let supplementarySection = supplementarySection(
                for: document,
                listing: listing,
                offer: offer,
                buyer: buyer,
                seller: seller
            ) {
                sections.append(supplementarySection)
            }

            var yOffset: CGFloat = 40
            for (index, section) in sections.enumerated() {
                let attributes = index == 0 ? titleAttributes : bodyAttributes
                let height = section.boundingRect(
                    with: CGSize(width: pageRect.width - 80, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height.rounded(.up) + 12
                let rect = CGRect(x: 40, y: yOffset, width: pageRect.width - 80, height: height)
                section.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                yOffset += height + 16
            }
        }
    }

    private static func formattedSignatureDate(_ date: Date?) -> String {
        guard let date else {
            return "Waiting"
        }
        return DateFormatter.saleDocumentDate.string(from: date)
    }

    private static func supplementarySection(
        for document: SaleDocument,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile
    ) -> String? {
        switch document.kind {
        case .settlementSummaryPDF:
            return """
            Closeout summary
            Buyer: \(buyer.name)
            Seller: \(seller.name)
            Final price: \(Currency.aud.string(from: NSNumber(value: offer.amount)) ?? "$\(offer.amount)")
            Settlement date: \(formattedSignatureDate(offer.settlementCompletedAt))
            Property suburb: \(listing.address.suburb)
            """
        case .handoverChecklistPDF:
            return """
            Handover checklist
            1. Keys and remote controls handed over.
            2. Final inspection and property condition confirmed.
            3. Utilities, meter reads, and insurance transfer checked.
            4. Settlement funds and legal closeout confirmed.
            5. Buyer and seller both retain the signed contract and settlement statement.
            """
        case .contractPacketPDF,
             .councilRatesNoticePDF,
             .identityCheckPackPDF,
             .buyerFinanceProofPDF,
             .sellerOwnershipEvidencePDF,
             .signedContractPDF,
             .settlementStatementPDF,
             .reviewedContractPDF,
             .settlementAdjustmentPDF:
            return nil
        }
    }

    private static func renderConciergePDFData(
        title: String,
        createdAt: Date,
        listing: PropertyListing,
        offer: OfferRecord,
        buyer: UserProfile,
        seller: UserProfile,
        booking: PostSaleConciergeBooking,
        supportingSection: String
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.darkGray
            ]

            let documentDate = DateFormatter.saleDocumentDate.string(from: createdAt)
            let formattedAmount = Currency.aud.string(from: NSNumber(value: offer.amount)) ?? "$\(offer.amount)"

            let sections = [
                "\(title)\nGenerated \(documentDate)",
                """
                Property
                \(listing.title)
                \(listing.address.street), \(listing.address.suburb) \(listing.address.state) \(listing.address.postcode)
                """,
                """
                Sale record
                Final sale price: \(formattedAmount)
                Buyer: \(buyer.name)
                Seller: \(seller.name)
                Settlement complete: \(formattedSignatureDate(offer.settlementCompletedAt))
                """,
                """
                Concierge booking
                Provider: \(booking.provider.name)
                Service: \(booking.serviceKind.title)
                Status: \(booking.status.title)
                Booked by: \(booking.bookedByName)
                Notes: \(booking.notes.isEmpty ? "No extra notes recorded." : booking.notes)
                """,
                supportingSection
            ]

            var yOffset: CGFloat = 40
            for (index, section) in sections.enumerated() {
                let attributes = index == 0 ? titleAttributes : bodyAttributes
                let height = section.boundingRect(
                    with: CGSize(width: pageRect.width - 80, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                ).height.rounded(.up) + 12
                let rect = CGRect(x: 40, y: yOffset, width: pageRect.width - 80, height: height)
                section.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
                yOffset += height + 16
            }
        }
    }

    private static func conciergeFileName(
        prefix: String,
        booking: PostSaleConciergeBooking,
        listing: PropertyListing
    ) -> String {
        let listingLabel = listing.address.suburb
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: ",", with: "")
        return "real-o-who-\(booking.serviceKind.rawValue)-\(prefix)-\(listingLabel).pdf"
    }

    private static func currencyLabel(for amount: Int?) -> String? {
        guard let amount else { return nil }
        return Currency.aud.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

struct SaleDocumentPreviewSheet: UIViewControllerRepresentable {
    let document: PreparedSaleDocument

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.document = document
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var document: PreparedSaleDocument

        init(document: PreparedSaleDocument) {
            self.document = document
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            PreviewItem(title: document.title, url: document.url)
        }
    }

    private final class PreviewItem: NSObject, QLPreviewItem {
        let previewItemTitle: String?
        let previewItemURL: URL?

        init(title: String, url: URL) {
            previewItemTitle = title
            previewItemURL = url
        }
    }
}

struct TrackedShareSheet: UIViewControllerRepresentable {
    let title: String
    let items: [Any]
    var onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.setValue(title, forKey: "subject")
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete(completed)
        }
    }
}

private extension DateFormatter {
    static let saleDocumentDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
