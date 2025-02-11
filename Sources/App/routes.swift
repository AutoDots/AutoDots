import Vapor
import Foundation

// Data structure for the CTA button
struct CTAButton: Content {
    let link: String
    let text: String
}

// Data structure for the index page context
struct IndexContext: Content {
    let learnMoreLink: String?
    let supportedCodes: String
    let specificCodesLink: String?
    let ctaButton: CTAButton?
}

// Struct to decode the translation request body for /api/translate
struct TranslationRequest: Content {
    let inputText: String
    let brailleGrade: String // We receive grade, but currently only using Grade 1 logic
}

func routes(_ app: Application) throws {
    // Root path will render index
    app.get { req async throws -> View in
        let context = IndexContext(
            learnMoreLink: "/about",
            supportedCodes: "UEB (Unified English Braille) grade 1",
            specificCodesLink: "/supported-codes",
            ctaButton: CTAButton(
                link: "/try-now",
                text: "Start Translating Now"
            )
        )
        return try await req.view.render("index", context)
    }

    app.get("translate") { req async throws -> View in
        return try await req.view.render("translate") // Render the translate.leaf template
    }

    // API endpoint for text to braille translation
    app.post("api", "translate") { req async throws -> String in
        let translationRequest = try req.content.decode(TranslationRequest.self)
        let inputText = translationRequest.inputText
        let brailleOutput = textToUncontractedBraille(inputText) // Call your translation function from BrailleTranslator.swift
        return brailleOutput // Return the braille output as a String
    }
}