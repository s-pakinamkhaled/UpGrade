FROM python:3.10-slim

WORKDIR /app
COPY backend/requirements.txt /app/backend/requirements.txt
COPY ai/requirements.txt /app/ai/requirements.txt

RUN pip install --no-cache-dir -r /app/backend/requirements.txt \
    && pip install --no-cache-dir -r /app/ai/requirements.txt

COPY backend/ /app/backend/
COPY ai/ /app/ai/

WORKDIR /app/backend

EXPOSE 8001

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]