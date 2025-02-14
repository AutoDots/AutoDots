import Vapor
import Foundation
import MathCat

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
        let brailleGrade = translationRequest.brailleGrade

        if brailleGrade == "maths" {
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFilename = "mathml-output-\(UUID().uuidString).xml" // Changed extension to .xml
            let tempFileURL = tempDirectory.appendingPathComponent(tempFilename)
            let tempFilePath = tempFileURL.path
			print(tempFilePath)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/latexmlmath")
            process.arguments = [
                "--strict",
				"--verbose",
				"--verbose",
                "--pmml=\(tempFilePath)",
                "-" // Read from stdin
            ]

            let inputPipe = Pipe() // Create a Pipe for input
            process.standardInput = inputPipe // Set process's standardInput to the Pipe
            let outputPipe = Pipe() // Create a Pipe for output
            process.standardOutput = outputPipe // Set process's standardOutput
            let errorPipe = Pipe() // Create a Pipe for error
            process.standardError = errorPipe // Set process's standardError


            do {


                try inputPipe.fileHandleForWriting.write(Data(inputText.utf8)) // Use inputPipe to write
                try inputPipe.fileHandleForWriting.close() // Close the writing end of the input pipe

                process.waitUntilExit()
                try process.run()
                if process.terminationStatus == 0 {
                    // 2. Read MathML from temporary file
                    let mathMLData = try Data(contentsOf: tempFileURL)
                    guard let mathMLString = String(data: mathMLData, encoding: .utf8) else {
                        throw Abort(.internalServerError, reason: "Failed to read MathML from temp file")
                    }

                    // 3. Use MathCat to translate MathML to Braille
                    do {
                        _ = try MathCat.setMathML(mathmlString: mathMLString) // Ignoring annotated MathML output for now
                        let brailleOutput = try MathCat.getBraille()
                        // 4. Clean up temporary file
                        try FileManager.default.removeItem(at: tempFileURL)
                        return brailleOutput
                    } catch {
                        // MathCat Braille translation error
                        try? FileManager.default.removeItem(at: tempFileURL) // Clean up even on error
                        throw Abort(.internalServerError, reason: "MathCAT Braille translation failed: \(error)")
                    }

                } else {
                    // latexmlmath failed - get error message from stderr
                    let errorData = try errorPipe.fileHandleForReading.readDataToEndOfFile() // Use errorPipe to read error
                    let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown LaTeX conversion error"
                    try? FileManager.default.removeItem(at: tempFileURL) // Clean up on error
                    throw Abort(.badRequest, reason: "LaTeX conversion failed: \(errorMessage)") // Return 400 error to client
                }

            } catch {
                // Process execution or file reading error
                try? FileManager.default.removeItem(at: tempFileURL) // Clean up on error
                throw Abort(.internalServerError, reason: "Error during LaTeX processing: \(error)")
            }

        } else {
            // --- Existing Grade 1 Text-to-Braille Conversion ---
            return textToUncontractedBraille(inputText) // Call your Grade 1 translation function
        }
    }
}
