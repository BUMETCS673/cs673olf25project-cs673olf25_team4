FROM python:3.12-alpine3.21

# Prevent Python from writing .pyc files and ensure logs go to terminal
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

# Install system dependencies + bash + openssl for SSL certificate handling
RUN apk add --no-cache gcc musl-dev libffi-dev bash openssl

# Copy and install Python dependencies
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend app code
COPY app ./app
COPY run_tests.sh ./run_tests.sh
COPY tests ./tests

# Create SSL certificate directory
RUN mkdir -p /app/ssl

ENV PORT=8000

# Default to HTTP, can be overridden with environment variables and volume mounts
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
