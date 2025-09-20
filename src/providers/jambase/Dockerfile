FROM python:3.12-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apk add --no-cache gcc musl-dev libffi-dev

COPY providers/jambase/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy jambase provider code
COPY providers/jambase /app

# Copy backend code
COPY backend /app/backend

# Each provider exposes its own FastAPI app in main.py
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8002"]
