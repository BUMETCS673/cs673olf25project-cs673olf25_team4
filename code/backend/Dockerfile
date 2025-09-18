FROM python:3.12-alpine3.21

# Prevents Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1
# Ensures logs are sent straight to terminal
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system deps (for pip, uvicorn, etc.)
RUN apk add --no-cache gcc musl-dev libffi-dev
ARG CODE_ROOT=./code
COPY ${CODE_ROOT}/backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY ${CODE_ROOT}/backend/app ./app

# Copy frontend static files into the image so the backend can serve the SPA.
# IMPORTANT: this COPY expects the build context to include the frontend folder.
# Example: from the `code/` directory run:
#   docker build -f backend/Dockerfile .
# which makes `./frontend/public` available to this Dockerfile.
# Default frontend path when CODE_ROOT is the repository root. FRONTEND_PATH is
# relative to the build context so we construct it using CODE_ROOT.
ARG FRONTEND_PATH=${CODE_ROOT}/frontend/public
# The SOURCE for COPY is relative to the build context. When building from the
# repository root (Cloud Build / Cloud Run) the default FRONTEND_PATH works.
COPY ${FRONTEND_PATH} /app/frontend_public

ENV PORT=8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
