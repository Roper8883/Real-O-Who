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

            let sections = [
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
                Document summary
                \(document.summary)
                """
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

    private static func formattedSignatureDate(_ date: Date?) -> String {
        guard let date else {
            return "Waiting"
        }
        return DateFormatter.saleDocumentDate.string(from: date)
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
