FROM python:3.12-alpine3.21

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apk add --no-cache gcc musl-dev libffi-dev

COPY providers/groq/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy ticketmaster_service provider code
COPY providers/groq /app

# Each provider exposes its own FastAPI app in main.py
CMD ["uvicorn", "groq_service:app", "--host", "0.0.0.0", "--port", "8000"]
