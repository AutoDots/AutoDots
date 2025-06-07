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
    let brailleGrade: String // Currently, only Grade 1 logic is used.
}

// Stub function for uncontracted braille conversion.
// Replace this with your actual conversion logic.

func routes(_ app: Application) throws {
    // Root path will render the index view.
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
        return try await req.view.render("home")
    }
    
    // Render the translate page.
    app.get("translate") { req async throws -> View in
        return try await req.view.render("translate")
    }
    
    // GET route for the chat page that renders chat.leaf.
    app.get("chat") { req async throws -> View in
        return try await req.view.render("chat")
    }
    
    // POST route for chat that calls the braille_translator.py script.
    app.post("chat") { req async throws -> View in
        // Extract the text input from the form submission.
        let inputText = try req.content.get(String.self, at: "text")
        
        // Create a Process to call the braille translator script.
        let process = Process() // If your script is executable, you can call it directly.
        // Otherwise, use a Python interpreter, e.g., "/usr/bin/python3".
        process.executableURL = URL(fileURLWithPath: "/home/server/BrailleManager/braille_translator.py")
        process.arguments = [inputText]
        
        // Setup pipes to capture standard output and error.
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
        } catch {
            return try await req.view.render("chat", ["errorMessage": "Failed to start translator script: \(error)"])
        }
        
        // Wait for the process to complete.
        process.waitUntilExit()
        
        // Read the outputs.
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        let errorString = String(data: errorData, encoding: .utf8) ?? ""
        
        // Check if the process completed successfully.
        if process.terminationStatus == 0 {
            return try await req.view.render("chat", ["output": outputString, "inputText": inputText])
        } else {
            return try await req.view.render("chat", ["errorMessage": errorString])
        }
    }
    
    // API endpoint for text-to-braille translation.
    app.post("api", "translate") { req async throws -> String in
        let translationRequest = try req.content.decode(TranslationRequest.self)
        let inputText = translationRequest.inputText
        let brailleGrade = translationRequest.brailleGrade

        if brailleGrade == "maths" {
            // Create a temporary file to hold MathML output.
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFilename = "mathml-output-\(UUID().uuidString).xml"
            let tempFileURL = tempDirectory.appendingPathComponent(tempFilename)
            let tempFilePath = tempFileURL.path
            print("Temp file path: \(tempFilePath)")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/latexmlmath")
            process.arguments = [
                "--strict",
                "--verbose",
                "--verbose",
                "--pmml=\(tempFileURL.path)",
                "-"
            ]

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                print("Starting latexmlmath process...")
                try process.run()

                print("Writing to input pipe...")
                try inputPipe.fileHandleForWriting.write(contentsOf: Data(inputText.utf8))
                try inputPipe.fileHandleForWriting.close()
                print("Input pipe closed.")

                let output = try await Task { () -> String in
                    print("Waiting for process to finish...")
                    process.waitUntilExit()
                    print("Process finished. Termination status: \(process.terminationStatus)")

                    // Capture stdout and stderr.
                    let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
                    let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()

                    let outputString = String(data: outputData, encoding: .utf8) ?? ""
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""

                    print("latexmlmath stdout: \(outputString)")
                    print("latexmlmath stderr: \(errorString)")
					 if process.terminationStatus == 0 {
                        print("Reading MathML from file...")
                        let mathMLData = try Data(contentsOf: tempFileURL)
                        
                        guard let mathMLString = String(data: mathMLData, encoding: .utf8) else {
                            throw Abort(.internalServerError, reason: "Failed to read MathML from temp file")
                        }
                        print("MathML read successfully")
                        print("MathML string: \(mathMLString)")
                        print("Setting rules directory")
                        try MathCat.setRulesDir(rulesDirLocation: "rules")
                        print("Calling MathCat...")
                        print("Enabling UEB")
                        try MathCat.setPreference(pref: "BrailleCode", value: "UEB")
                        
                        _ = try MathCat.setMathML(mathmlString: mathMLString)
                        let brailleOutput = try MathCat.getBraille()
                        print("Braille output: \(brailleOutput)")

                        print("Cleaning up temp file...")
                        try FileManager.default.removeItem(at: tempFileURL)
                        print("Temp file removed.")
                        return brailleOutput

                    } else {
                        try? FileManager.default.removeItem(at: tempFileURL)
                        throw Abort(.badRequest, reason: "LaTeX conversion failed: \(errorString)")
                    }
                }.value

                return output

            } catch {
                try? FileManager.default.removeItem(at: tempFileURL)
                print("Error during processing: \(error)")
                throw Abort(.internalServerError, reason: "Error during LaTeX processing: \(error)")
            }

        } else {
            return textToUncontractedBraille(inputText)
        }
    }
}