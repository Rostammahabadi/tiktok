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
    if request.method != "POST":
        return make_response(("Method not allowed", 405))

    openai.api_key = os.environ.get("OPENAI_API_KEY", "")
    if not openai.api_key:
        return _json_response({"error": "Missing OPENAI_API_KEY env var"}, 400)

    try:
        data = request.get_json(silent=True) or {}
    except:
        return _json_response({"error": "Invalid JSON"}, 400)

    subject = data.get("subject", "Unknown Subject")
    topic = data.get("topic", "Unknown Topic")
    age_group = data.get("ageGroup", "middle_school")
    duration = data.get("duration", "short")
    include_quiz = data.get("includeQuiz", False)
    include_examples = data.get("includeExamples", False)

    # 1) Create a short TTS-friendly script with ChatCompletion
    #    (Similar to your original logic)
    system_prompt_1 = (
        "You are an expert educational script writer. "
        "Write a concise, natural-sounding voiceover script for text-to-speech. "
        "Do not include stage directions or 'End of lesson'. "
        "Use minimal new lines and keep the language straightforward. "
        "If a quiz is included, place it at the very end with a short phrase leading into it, e.g., 'Now here's your quiz'. "
        "Return only raw text—no disclaimers."
    )
    user_prompt_1 = (
        f"Write a script to teach {topic} in {subject}, aimed at {age_group}, duration {duration}, "
        f"includeQuiz={include_quiz}, includeExamples={include_examples}. "
        "Output one paragraph, TTS-friendly, end with quiz if includeQuiz=True. "
        "No stage directions."
    )
    client = wrap_openai(openai)
    try:
        resp_1 = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt_1},
                {"role": "user", "content": user_prompt_1},
            ],
            temperature=0.7,
        )
        script_text = resp_1.choices[0].message.content
    except Exception as e:
        return _json_response({"error": f"Script generation error: {str(e)}"}, 500)

    # 2) Take the generated script_text and embed it in Manim code
    #    that uses the manim-voiceover plugin with OpenAIService
    #    We'll instruct GPT again to produce actual manim code:
    system_prompt_2 = (
        "You are an advanced Manim developer using manim-voiceover with ElevenLabsService. "
        "Given the text, produce a Python script that:\n"
        "1) Configures a vertical 9:16 aspect ratio using config.pixel_width=1080 and config.pixel_height=1920.\n"
        "2) Defines a class GeneratedVideoScene(VoiceoverScene) using:\n"
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
        "5) Keep text scaled small enough to avoid overflow on a vertical mobile screen.\n"
        "6) End with a fade out or final message if the script includes a quiz.\n"
        "7) Return only valid Python code, with no disclaimers, no triple backticks, and no extra commentary.\n"
        "8) Make sure the import statement for ElevenLabsService always comes from 'manim_voiceover.services.elevenlabs'."
    )
    user_prompt_2 = (
        f"Here is the TTS script:\n{script_text}\n\n"
        "Please create manim-voiceover code in a single Python file named 'GeneratedVideoScene'. "
        "No triple backticks, no commentary—just raw Python code."
    )

    try:
        resp_2 = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": system_prompt_2},
                {"role": "user", "content": user_prompt_2},
            ],
            temperature=0.7,
        )
        manim_code = resp_2.choices[0].message.content
    except Exception as e:
        return _json_response({"error": f"Manim code generation error: {str(e)}"}, 500)

    # Return the final manim code with voiceover
    return _json_response({"manim_code": manim_code}, 200)

def _json_response(body, status=200):
    response = make_response((json.dumps(body), status))
    response.headers["Content-Type"] = "application/json"
    return response