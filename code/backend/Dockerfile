FROM python:3.12-alpine3.21

# Prevents Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1
# Ensures logs are sent straight to terminal
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system deps (for pip, uvicorn, etc.)
RUN apk add --no-cache gcc musl-dev libffi-dev

COPY ./backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY ./backend/app ./app

# Copy frontend static files into the image so the backend can serve the SPA.
# IMPORTANT: this COPY expects the build context to include the frontend folder.
# Example: from the `code/` directory run:
#   docker build -f backend/Dockerfile .
# which makes `./frontend/public` available to this Dockerfile.
ARG FRONTEND_PATH=./frontend/public
# The SOURCE for COPY is relative to the build context. If you build from the
# repository root, pass --build-arg FRONTEND_PATH=./code/frontend/public
COPY ${FRONTEND_PATH} /app/frontend_public

ENV PORT=8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
