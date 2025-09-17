FROM python:3.12-alpine3.21

# Prevents Python from writing pyc files
ENV PYTHONDONTWRITEBYTECODE=1
# Ensures logs are sent straight to terminal
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install system deps (for pip, uvicorn, etc.)
RUN apk add --no-cache gcc musl-dev libffi-dev

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./app ./app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
