import os
import json
import tempfile
import subprocess
import openai
import time
from langsmith import traceable
from langsmith.wrappers import wrap_openai

from flask import Flask, request, make_response
from google.cloud import storage

app = Flask(__name__)

@traceable
def fix_manim_code(raw_code):
    """
    Uses OpenAI to remove or fix environment variable logic that sets
    pixel_width/pixel_height as floats. Also ensures no .scale() calls
    produce float sizes. Returns safe Python code for Manim.
    """
    print("[DEBUG] Entering fix_manim_code. Raw code length:", len(raw_code))
    openai_api_key = os.environ.get("OPENAI_API_KEY", "")
    if not openai_api_key:
        print("[WARN] No OPENAI_API_KEY found. Returning raw code.")
        return raw_code

    # Debugging: confirm which openai version
    try:
        import pkg_resources
        openai_ver = pkg_resources.get_distribution("openai").version
        print("[DEBUG] openai library version:", openai_ver)
    except Exception as e:
        print("[WARN] Could not determine openai version:", e)

    system_prompt = (
        "You are an advanced Manim developer. "
        "Rewrite the code so that any pixel_width/pixel_height are forced to be integers, "
        "remove environment variable float logic, and ensure no .scale() calls produce floats. "
        "Remove or omit any 'line_spacing' parameters for Text or MathTex. "
        "If line_spacing is not explicitly provided, add it. "
        "No triple backticks or commentary—only valid Python code with correct indentation. "
    )

    user_prompt = f"Here is the original code:\n\n{raw_code}\n\nPlease fix it now."
    client = wrap_openai(openai)
    try:
        print("[DEBUG] Sending code to GPT for cleaning...")
        fix_resp = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            temperature=0.0,
        )
        cleaned_code = fix_resp.choices[0].message.content
        print("[DEBUG] GPT returned cleaned code (first 200 chars):", cleaned_code[:200])
        return cleaned_code
    except Exception as e:
        print("[WARN] Could not fix Manim code with GPT:", e)
        print("[WARN] Returning raw code unmodified.")
        return raw_code

@app.route("/", methods=["POST"])
def render_and_upload():
    """
    Expects JSON:
    {
      "manim_code": "...",
      "outputBucket": "my-bucket",
      "outputPath": "videos/final_lesson.mp4",
      "qualityFlag": "-qm"  (optional)
    }
    """
    start_time = time.time()
    print("[DEBUG] Incoming request received.")
    data = request.get_json(silent=True) or {}
    print("[DEBUG] Incoming JSON:", data)

    manim_code = data.get("manim_code", "")
    out_bucket = data.get("outputBucket", "")
    out_path = data.get("outputPath", "")
    quality_flag = data.get("qualityFlag", "-qm")

    # Check for missing fields
    if not (manim_code and out_bucket and out_path):
        print("[ERROR] Missing inputs. Cannot proceed.")
        return _json_resp({"error": "Missing inputs"}, 400)

    # 1) Run code through GPT to fix float issues, .scale() calls, etc.
    print("[DEBUG] Fixing manim code via GPT if needed...")
    fixed_code = fix_manim_code(manim_code)
    fixed_code = fixed_code.replace("```python", "").replace("```", "")
    # 2) Write the fixed Manim code to /tmp
    print("[DEBUG] Writing fixed code to a temp file...")
    try:
        with tempfile.NamedTemporaryFile(suffix=".py", delete=False) as tmp_py:
            manim_file_path = tmp_py.name
            tmp_py.write(fixed_code.encode("utf-8"))
    except Exception as e:
        print("[ERROR] Could not write code to temp file:", e)
        return _json_resp({"error": "Failed to write temp code", "details": str(e)}, 500)

    # 3) Render with Manim (we assume audio is built-in to the output)
    scene_name = "GeneratedVideoScene"
    cmd = [
        "manim",
        quality_flag,  # e.g. "-ql" or "-qm" or "-qh"
        manim_file_path,
        scene_name
    ]
    print("[DEBUG] Running manim command:", cmd)

    # Set environment so it won't do version checks
    env = dict(os.environ)
    env["MANIM_DISABLE_VERSION_CHECK"] = "1"

    try:
        result = subprocess.run(
            cmd,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=300,  # e.g. 2 minutes
            env=env
        )
        print("[DEBUG] Manim output (stdout):", result.stdout)
        if result.stderr:
            print("[DEBUG] Manim output (stderr):", result.stderr)
    except subprocess.TimeoutExpired as e:
        elapsed = time.time() - start_time
        print(f"[ERROR] Manim timed out after {elapsed:.2f} seconds.")
        return _json_resp({"error": "Manim timed out", "details": str(e)}, 504)
    except subprocess.CalledProcessError as e:
        print("[ERROR] Manim rendering failed. Return code:", e.returncode)
        print("[ERROR] stderr:", e.stderr)
        return _json_resp({"error": "Manim rendering failed", "details": e.stderr}, 500)

    # 4) Locate the .mp4
    print("[DEBUG] Searching for .mp4 output...")
    video_path = find_manim_output(manim_file_path, scene_name)
    if not video_path:
        print("[ERROR] No .mp4 found in expected paths.")
        return _json_resp({"error": "No .mp4 found"}, 500)

    # 5) Upload final to GCS
    print(f"[DEBUG] Uploading final video to gs://{out_bucket}/{out_path}")
    try:
        out_client = storage.Client()
        out_b = out_client.bucket(out_bucket)
        out_blob = out_b.blob(out_path)
        out_blob.upload_from_filename(video_path, content_type="video/mp4")
    except Exception as e:
        print("[ERROR] Could not upload final video to GCS:", e)
        return _json_resp({"error": "Upload to GCS failed", "details": str(e)}, 500)

    elapsed = time.time() - start_time
    print(f"[DEBUG] Successfully rendered & uploaded video in {elapsed:.2f} seconds.")
    return _json_resp({"finalVideoUrl": f"gs://{out_bucket}/{out_path}"}, 200)

def find_manim_output(tmp_py_path, scene_name):
    import os
    base_name = os.path.basename(tmp_py_path)
    root = os.path.splitext(base_name)[0]
    possible_dirs = ["480p15", "720p30", "1080p60"]
    for d in possible_dirs:
        candidate = f"media/videos/{root}/{d}/{scene_name}.mp4"
        print("[DEBUG] Checking for:", candidate)
        if os.path.exists(candidate):
            print("[DEBUG] Found video at:", candidate)
            return candidate
    # fallback
    media_root = f"media/videos/{root}"
    print("[DEBUG] Fallback: searching recursively in", media_root)
    if os.path.exists(media_root):
        for rt, dirs, files in os.walk(media_root):
            if f"{scene_name}.mp4" in files:
                found_path = os.path.join(rt, f"{scene_name}.mp4")
                print("[DEBUG] Found video at:", found_path)
                return found_path
    print("[DEBUG] No .mp4 found at all.")
    return None

def _json_resp(obj, status=200):
    print("[DEBUG] Returning JSON response with status", status, ":", obj)
    return make_response(
        (json.dumps(obj), status, {"Content-Type": "application/json"})
    )

if __name__ == "__main__":
    print("[DEBUG] Starting Flask app on port 8080...")
    app.run(host="0.0.0.0", port=8080, debug=True)