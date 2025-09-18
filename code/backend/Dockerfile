FROM python:3.12-alpine3.21

# Prevent Python from writing .pyc files and ensure logs go to terminal
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app
RUN apk add --no-cache gcc musl-dev libffi-dev

# Copy and install Python dependencies (paths are relative to the build context)
COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend app code
COPY app ./app

ENV PORT=8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
