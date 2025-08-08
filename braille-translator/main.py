import os
import subprocess
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import google.generativeai as genai
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure the Gemini API
api_key = os.getenv("GOOGLE_API_KEY")
if not api_key:
    raise ValueError("GOOGLE_API_KEY not found in .env file")
genai.configure(api_key=api_key)

# --- Braille Translation Function ---
def translate_braille(text_to_translate: str, braille_grade: str) -> str:
    """
    Translates text to Braille using the liblouis `lou_translate` command.

    Args:
        text_to_translate: The text to be translated.
        braille_grade: The desired Braille grade ('g1' or 'g2').

    Returns:
        The Braille translation as a string, or an error message.
    """
    try:
        # Construct the command for liblouis
        # We use unicode.dis to get Unicode Braille character output
        # The table `en-ueb-g1.ctb` or `en-ueb-g2.ctb` specifies the translation rules.
        command = f"lou_translate unicode.dis,en-ueb-{braille_grade}.ctb"

        # Run the command using subprocess
        process = subprocess.run(
            command,
            input=text_to_translate,
            capture_output=True,
            text=True,
            shell=True,
            check=True
        )
        return process.stdout.strip()
    except subprocess.CalledProcessError as e:
        return f"Error during Braille translation: {e.stderr}"
    except FileNotFoundError:
        return "Error: `lou_translate` command not found. Is liblouis installed and in the PATH?"


# --- FastAPI App Setup ---
app = FastAPI()

# --- Gemini Model and Function Calling Setup ---
# Define the function for the model to call
braille_translation_tool = {
    "name": "translate_braille",
    "description": "Translates a given text into either grade 1 or grade 2 Braille.",
    "parameters": {
        "type": "object",
        "properties": {
            "text_to_translate": {
                "type": "string",
                "description": "The text that needs to be translated to Braille."
            },
            "braille_grade": {
                "type": "string",
                "enum": ["g1", "g2"],
                "description": "The grade of Braille to translate to. Should be 'g1' for Grade 1 or 'g2' for Grade 2."
            }
        },
        "required": ["text_to_translate", "braille_grade"]
    }
}

# Initialize the generative model with the function declaration
model = genai.GenerativeModel(
    model_name='gemini-1.5-flash',
    tools=[braille_translation_tool]
)


# --- API Endpoints ---
class ChatRequest(BaseModel):
    query: str

@app.post("/chat")
async def chat_handler(chat_request: ChatRequest):
    """
    Handles chat requests, using Gemini to understand the query and
    call the Braille translation function if needed.
    """
    try:
        chat_session = model.start_chat()
        response = chat_session.send_message(
            chat_request.query,
        )

        # Check if the model wants to call the function
        if response.function_calls:
            fc = response.function_calls[0]
            if fc.name == "translate_braille":
                # Call the actual Python function
                result = translate_braille(
                    text_to_translate=fc.args['text_to_translate'],
                    braille_grade=fc.args['braille_grade']
                )

                # Send the function's result back to the model
                response = chat_session.send_message(
                    f"Function Response: {result}",
                )

        return JSONResponse(content={"response": response.text})

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# Serve static files (for the frontend)
app.mount("/static", StaticFiles(directory="frontend/dist"), name="static")

@app.get("/", response_class=HTMLResponse)
async def read_root():
    # Placeholder for serving the main HTML page
    return """
    <html>
        <head>
            <title>Braille Translator</title>
        </head>
        <body>
            <h1>Braille Translator (Work in Progress)</h1>
        </body>
    </html>
    """

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
