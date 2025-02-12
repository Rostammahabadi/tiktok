# ====================
# 1) Builder Stage
# ====================
FROM python:3.9-slim AS builder

# Dev libraries needed for building manim, python-sox, mapbox-earcut, pycairo, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    meson \
    ninja-build \
    libcairo2-dev \
    libpango1.0-dev \
    sox \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY requirements.txt .

# 1) Upgrade pip/setuptools/wheel
# 2) Install scikit-build + scikit-build-core + mesonpy + cmake + ninja (handles many modern Python build backends)
# 3) Install numpy + typing_extensions (so python-sox can build)
RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir \
       cython \
       meson \
       meson-python \
       pybind11 \
       cmake \
       ninja \
       scikit-build \
       scikit-build-core \
    && pip install --no-cache-dir \
       typing_extensions \
       numpy

# 4) Now install everything else, but DISABLE build isolation
RUN pip install --no-cache-dir --no-build-isolation -r requirements.txt

# 5) Install manim-voiceover[elevenlabs] specifically
RUN pip install --no-cache-dir --no-build-isolation "manim-voiceover[elevenlabs]"
RUN pip install --no-cache-dir --no-build-isolation "manim-voiceover[transcribe]"
RUN pip install --no-cache-dir --upgrade torch torchaudio --index-url https://download.pytorch.org/whl/cpu
# ====================
# 2) Final Stage
# ====================
FROM python:3.9-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    pkg-config \
    meson \
    ninja-build \
    libcairo2-dev \
    libpango1.0-dev \
    libglib2.0-dev \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-binaries \
    dvipng \
    ghostscript \
    dvisvgm \
    latexmk \
    libharfbuzz-dev \
    libfreetype6-dev \
    libfribidi-dev \
    pybind11-dev \ 
    sox \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

WORKDIR /app
ARG CACHE_BUST=1
RUN echo "Cache bust arg is $CACHE_BUST"
COPY main.py main.py

COPY .env .env
COPY .env /app/.env
ENV PORT=8080
ENV FFMPEG_BINARY=ffmpeg
ENV MANIM_VOICEOVER_NO_ENV_CREATION=1
EXPOSE 8080
CMD ["python", "main.py"]