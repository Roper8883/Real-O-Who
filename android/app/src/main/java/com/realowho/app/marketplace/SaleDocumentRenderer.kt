package com.realowho.app.marketplace

import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import java.io.File
import java.io.FileOutputStream
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object SaleDocumentRenderer {
    fun render(
        context: Context,
        document: SaleDocument,
        listing: SaleListing,
        offer: SaleOffer,
        buyer: com.realowho.app.auth.MarketplaceUserProfile,
        seller: com.realowho.app.auth.MarketplaceUserProfile
    ): File {
        val directory = File(context.cacheDir, "sale-documents").apply { mkdirs() }
        val outputFile = File(directory, document.fileName)

        document.attachmentBase64?.let { encoded ->
            val attachment = runCatching { java.util.Base64.getDecoder().decode(encoded) }.getOrNull()
            if (attachment != null) {
                outputFile.writeBytes(attachment)
                return outputFile
            }
        }

        val pdfDocument = PdfDocument()
        val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
        val page = pdfDocument.startPage(pageInfo)
        val canvas = page.canvas

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 20f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val headingPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 13f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            textSize = 11f
        }

        var y = 42f
        y = drawWrappedText(canvas, document.kind.title, titlePaint, 40f, y, 515f)
        y += 6f
        y = drawWrappedText(
            canvas,
            "Generated ${formatTimestamp(document.createdAt)}",
            bodyPaint,
            40f,
            y,
            515f
        )
        y += 18f

        y = drawSection(
            canvas,
            heading = "Property",
            lines = listOf(
                listing.title,
                "${listing.address.street}, ${listing.address.suburb} ${listing.address.state} ${listing.address.postcode}"
            ),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        y = drawSection(
            canvas,
            heading = "Deal terms",
            lines = listOf(
                "Offer amount: ${formatAmount(offer.amount)}",
                "Current status: ${offer.status.title}",
                "Conditions: ${offer.conditions}"
            ),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        y = drawSection(
            canvas,
            heading = "Buyer",
            lines = listOf(buyer.name, buyer.suburb),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        y = drawSection(
            canvas,
            heading = "Seller",
            lines = listOf(seller.name, seller.suburb),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        y = drawSection(
            canvas,
            heading = "Legal representatives",
            lines = listOf(
                "Buyer: ${offer.contractPacket?.buyerRepresentative?.name ?: "Pending"}",
                "Seller: ${offer.contractPacket?.sellerRepresentative?.name ?: "Pending"}"
            ),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        y = drawSection(
            canvas,
            heading = "Signatures",
            lines = listOf(
                "Buyer sign-off: ${offer.contractPacket?.buyerSignedAt?.let(::formatTimestamp) ?: "Waiting"}",
                "Seller sign-off: ${offer.contractPacket?.sellerSignedAt?.let(::formatTimestamp) ?: "Waiting"}"
            ),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )
        drawSection(
            canvas,
            heading = "Document summary",
            lines = listOf(document.summary),
            y = y,
            headingPaint = headingPaint,
            bodyPaint = bodyPaint
        )

        pdfDocument.finishPage(page)
        FileOutputStream(outputFile).use { output ->
            pdfDocument.writeTo(output)
        }
        pdfDocument.close()

        return outputFile
    }

    private fun drawSection(
        canvas: android.graphics.Canvas,
        heading: String,
        lines: List<String>,
        y: Float,
        headingPaint: Paint,
        bodyPaint: Paint
    ): Float {
        var nextY = drawWrappedText(canvas, heading, headingPaint, 40f, y, 515f)
        nextY += 6f
        lines.filter { it.isNotBlank() }.forEach { line ->
            nextY = drawWrappedText(canvas, line, bodyPaint, 40f, nextY, 515f)
            nextY += 4f
        }
        return nextY + 12f
    }

    private fun drawWrappedText(
        canvas: android.graphics.Canvas,
        text: String,
        paint: Paint,
        x: Float,
        y: Float,
        width: Float
    ): Float {
        var currentY = y
        wrapText(text, paint, width).forEach { line ->
            canvas.drawText(line, x, currentY, paint)
            currentY += paint.textSize + 4f
        }
        return currentY
    }

    private fun wrapText(text: String, paint: Paint, width: Float): List<String> {
        if (text.isBlank()) {
            return listOf("")
        }

        val words = text.split(Regex("\\s+"))
        val lines = mutableListOf<String>()
        var currentLine = ""

        words.forEach { word ->
            val candidate = if (currentLine.isEmpty()) word else "$currentLine $word"
            if (paint.measureText(candidate) <= width) {
                currentLine = candidate
            } else {
                if (currentLine.isNotEmpty()) {
                    lines += currentLine
                }
                currentLine = word
            }
        }

        if (currentLine.isNotEmpty()) {
            lines += currentLine
        }

        return lines
    }

    private fun formatAmount(amount: Int): String {
        return NumberFormat.getCurrencyInstance(Locale("en", "AU")).format(amount)
    }

    private fun formatTimestamp(timestamp: Long): String {
        val formatter = SimpleDateFormat("d MMM yyyy, h:mm a", Locale.getDefault())
        return formatter.format(Date(timestamp))
    }
}
