import os
import json
import openai
from flask import Request, make_response
import functions_framework  # For GCF v1 Python
from langsmith import traceable
from langsmith.wrappers import wrap_openai

@traceable
@functions_framework.http
def script_creation_gcf(request: Request):
    """
    POST JSON:
    {
      "subject": "Math",
      "topic": "Algebra",
      "ageGroup": "middle_school",
      "duration": "short",
      "includeQuiz": true,
      "includeExamples": false
    }

    Returns JSON:
    {
      "manim_code": "python code with voiceover using manim-voiceover"
    }
    """

    print("[DEBUG] Received request with method:", request.method)
    if request.method != "POST":
        print("[ERROR] Request method not allowed:", request.method)
        return make_response(("Method not allowed", 405))

    # Check for OpenAI API key
    openai.api_key = os.environ.get("OPENAI_API_KEY", "")
    if not openai.api_key:
        print("[ERROR] Missing OPENAI_API_KEY environment variable.")
        return _json_response({"error": "Missing OPENAI_API_KEY env var"}, 400)
    else:
        print("[DEBUG] Found OPENAI_API_KEY in environment variables.")

    # Try to parse JSON
    try:
        data = request.get_json(silent=True) or {}
        print("[DEBUG] Parsed JSON data:", data)
    except Exception as e:
        print("[ERROR] Could not parse JSON:", e)
        return _json_response({"error": "Invalid JSON"}, 400)

    subject = data.get("subject", "Unknown Subject")
    topic = data.get("topic", "Unknown Topic")
    age_group = data.get("ageGroup", "middle_school")
    duration = data.get("duration", "short")
    include_quiz = data.get("includeQuiz", False)
    include_examples = data.get("includeExamples", False)

    print("[DEBUG] Extracted parameters:")
    print("        subject      =", subject)
    print("        topic        =", topic)
    print("        age_group    =", age_group)
    print("        duration     =", duration)
    print("        include_quiz =", include_quiz)
    print("        include_examples =", include_examples)

    system_prompt_1 = (
        "You are an expert educational script writer. "
        "Generate a concise, natural-sounding voiceover script for text-to-speech. "
        "Do not include code, disclaimers, or stage directions. "
        "If includeQuiz is true, end with a short 'Now here's your quiz' line. "
        "Return only the raw text of the script—no extra commentary."
    )

    user_prompt_1 = (
        f"Write a script to teach {topic} in {subject}, aimed at {age_group}, duration {duration}, "
        f"includeQuiz={include_quiz}, includeExamples={include_examples}. "
        "Output one paragraph, TTS-friendly, end with quiz if includeQuiz=True. "
        "No stage directions."
    )

    # -------------------------------------------------------------------------
    # Step 1) Create a short TTS-friendly script with ChatCompletion
    # NOTE: The code references system_prompt_1 and user_prompt_1, but they're
    #       not defined in the snippet you provided. Replace or define them
    #       appropriately if you need this step, or remove it if not needed.
    # -------------------------------------------------------------------------
    # For example:
    #
    # system_prompt_1 = "You are a helpful assistant..."
    # user_prompt_1 = "Write a short TTS-friendly script about..."
    #
    # If you don't need them, remove the block below.
    # -------------------------------------------------------------------------

    print("[DEBUG] Starting Step 1: Creating short TTS-friendly script")
    try:
        # Make sure system_prompt_1 and user_prompt_1 are defined somewhere
        resp_1 = wrap_openai(openai).chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt_1},  # <-- Define or remove
                {"role": "user", "content": user_prompt_1},      # <-- Define or remove
            ],
            temperature=0.7,
        )
        script_text = resp_1.choices[0].message.content
        print("[DEBUG] Successfully created TTS-friendly script. Length:", len(script_text))
    except NameError as e:
        print("[ERROR] system_prompt_1 or user_prompt_1 not defined:", e)
        return _json_response({"error": "system_prompt_1 or user_prompt_1 not defined", "details": str(e)}, 500)
    except Exception as e:
        print("[ERROR] Script generation error:", e)
        return _json_response({"error": f"Script generation error: {str(e)}"}, 500)

    # -------------------------------------------------------------------------
    # Step 2) Generate full Manim code with voiceover via GPT
    # -------------------------------------------------------------------------
    system_prompt_2 = (
        "You are an advanced Manim developer using manim-voiceover with ElevenLabsService. "
        "Given the text, produce a Python script that:\n"
        "1) Configures a vertical 9:16 aspect ratio using config.pixel_width=1080 and config.pixel_height=1920.\n"
        "2) Defines a class GeneratedVideoScene(VoiceoverScene) by:\n"
        "   from manim_voiceover import VoiceoverScene\n"
        "   and from manim_voiceover.services.elevenlabs import ElevenLabsService.\n"
        "   IMPORTANT: Do NOT import from 'manim_voiceover.services.eleven_labs'; the correct module is 'manim_voiceover.services.elevenlabs'.\n"
        "3) In construct(), call:\n"
        "   self.set_speech_service(ElevenLabsService(\n"
        "       voice_name='Adam',\n"
        "       voice_id='pNInz6obpgDQGcFmaJgB',\n"
        "       voice_settings={'stability': 0.001, 'similarity_boost': 0.25}\n"
        "   ))\n"
        "4) Break the provided script into short segments, each wrapped in a with self.voiceover(text=\"...\"): block, "
        "   showing some textual or MathTex animations while the TTS is reading.\n"
        "5) Optimize for mobile (9:16) viewing by:\n"
        "   - Using font_size=28 or smaller for all Text and MathTex objects.\n"
        "   - Setting line_spacing=1.2 for improved readability.\n"
        "   - Using to_edge(UP, buff=0.5) to position text with proper padding.\n"
        "   - Breaking longer text into multiple lines by manually splitting.\n"
        "   - Centering text horizontally using .center() after positioning.\n"
        "   - Using scale(0.8) for complex mathematical expressions.\n"
        "6) Ensure text objects never overlap:\n"
        "   - Fade out or remove previous text (e.g., self.remove(text_obj)) before showing new text,\n"
        "     or position each successive text below or above previous ones.\n"
        "   - Always preview that lines remain readable and do not stack.\n"
        "7) End with a fade out or final message if the script includes a quiz.\n"
        "8) Return only valid Python code, with no disclaimers, no triple backticks, and no extra commentary.\n"
        "9) Make sure the import statement for ElevenLabsService always comes from 'manim_voiceover.services.elevenlabs'.\n"
        "10) Do NOT use any method like 'wrap_lines' that may cause an AttributeError in Text objects. "
        "    Handle line breaks by manually splitting the text or using a 'width' argument in the Text constructor.\n"
        "11) Use only methods that exist in standard Manim and manim-voiceover. Do not call any deprecated or non-existent "
        "    methods, attributes, or classes. The final script must run successfully without errors.\n"
    )
    user_prompt_2 = (
        f"Here is the TTS script:\n{script_text}\n\n"
        "Please create manim-voiceover code in a single Python file named 'GeneratedVideoScene'. "
        "No triple backticks, no commentary—just raw Python code."
    )

    print("[DEBUG] Starting Step 2: Generating Manim code with voiceover")
    try:
        resp_2 = wrap_openai(openai).chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system_prompt_2},
                {"role": "user", "content": user_prompt_2},
            ],
            temperature=0.7,
        )
        manim_code = resp_2.choices[0].message.content
        print("[DEBUG] Successfully generated Manim code. Length:", len(manim_code))
    except Exception as e:
        print("[ERROR] Manim code generation error:", e)
        return _json_response({"error": f"Manim code generation error: {str(e)}"}, 500)

    # -------------------------------------------------------------------------
    # Final: Return the manim code
    # -------------------------------------------------------------------------
    print("[DEBUG] Returning final Manim code in JSON response.")
    return _json_response({"manim_code": manim_code, "script_text": script_text}, 200)

def _json_response(body, status=200):
    """
    Helper to return a JSON response for Cloud Functions.
    """
    print(f"[DEBUG] _json_response called with status={status} and body={body}")
    response = make_response((json.dumps(body), status))
    response.headers["Content-Type"] = "application/json"
    return response