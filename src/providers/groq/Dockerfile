FROM python:3.12-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system dependencies including openssl for SSL certificate handling
RUN apk add --no-cache gcc musl-dev libffi-dev openssl

COPY providers/groq/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy groq provider code
COPY providers/groq /app

# Create SSL certificate directory
RUN mkdir -p /app/ssl

# Each provider exposes its own FastAPI app in groq_service.py
# Default to HTTP, can be overridden with environment variables and volume mounts
CMD ["uvicorn", "groq_service:app", "--host", "0.0.0.0", "--port", "8000"]
