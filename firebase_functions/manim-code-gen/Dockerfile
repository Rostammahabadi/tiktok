# Use a lightweight Python base image
FROM python:3.11-slim

# Install system packages needed for building manim, manim-voiceover, and their dependencies:
# - build-essential, gcc: C compiler and build tools
# - meson, ninja-build: used by some Python packages (e.g., pycairo) that use Meson
# - pkg-config: helps locate system libraries
# - libcairo2-dev, libpango1.0-dev, libpangocairo-1.0-0: for cairo, pango, pangocairo
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    meson \
    ninja-build \
    pkg-config \
    libcairo2-dev \
    libpango1.0-dev \
    libpangocairo-1.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Create a working directory
WORKDIR /app

# Copy your requirements file first, for caching
COPY requirements.txt .

# Install Python dependencies (including manim, manim-voiceover, etc.)
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your application code
COPY . .

# Expose port 8080 for Cloud Run
EXPOSE 8080

# Launch via the Functions Framework (replace --target if needed)
CMD ["functions-framework", "--target=script_creation_gcf", "--port=8080"]