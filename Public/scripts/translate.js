document.addEventListener('DOMContentLoaded', () => {
    const runButton = document.getElementById('runButton');
    const inputTextElement = document.getElementById('inputText');
    const brailleGradeElement = document.getElementById('brailleGrade');
    const brailleOutputElement = document.getElementById('brailleOutput');
    const copyButton = document.getElementById('copyButton'); // Get reference to the copy button

    // Initially disable the copy button
    copyButton.disabled = true;

    runButton.addEventListener('click', async (event) => {
        event.preventDefault(); // Prevent default form submission
        copyButton.disabled = true; // Disable copy button on new translation attempt
        brailleOutputElement.textContent = ""; // Clear previous output

        const inputText = inputTextElement.value;
        const brailleGrade = brailleGradeElement.value; // e.g., "grade1" or "grade2"

        if (!inputText) {
            alert("Please enter text to translate.");
            return;
        }

        try {
            const response = await fetch('/api/translate', { // Call the /api/translate route
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ // Send input text and braille grade as JSON
                    inputText: inputText,
                    brailleGrade: brailleGrade
                })
            });

            if (!response.ok) {
                const message = `HTTP error! status: ${response.status}`;
                throw new Error(message);
            }

            const brailleText = await response.text(); // Expecting plain text Braille output from backend
            brailleOutputElement.textContent = brailleText; // Display Braille in the output div
            copyButton.disabled = false; // Enable copy button after successful translation


        } catch (error) {
            // Display error as an alert to the user
            alert(`Translation Error: ${error.message}`);
            // Optionally still display a generic error message in the output area
            brailleOutputElement.textContent = "Error during translation.";
        }
    });

    copyButton.addEventListener('click', async () => {
        const brailleTextToCopy = brailleOutputElement.textContent;

        if (!brailleTextToCopy) {
            alert("No Braille text to copy."); // Should not happen if button is disabled correctly
            return;
        }

        try {
            await navigator.clipboard.writeText(brailleTextToCopy);
            alert("Braille text copied to clipboard!"); // Success feedback (you can improve this)
            // Optionally, you could change the button text temporarily to indicate success
            // copyButton.textContent = "Copied!";
            // setTimeout(() => { copyButton.textContent = "Copy Braille to Clipboard"; }, 2000); // Reset after 2 seconds

        } catch (clipboardError) {
            console.error("Clipboard API error:", clipboardError); // Keep console.error for debugging clipboard issues
            alert("Failed to copy Braille to clipboard. Please try again."); // Clipboard copy failed
        }
    });
});