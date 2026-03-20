FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY templates/ ./templates/
ENV PYTHONPATH=/app
ENV FLASK_APP=app.py

# ✅ Crear usuario sin privilegios y hacerle propietario de /app
RUN addgroup --system appgroup && \
    adduser --system --ingroup appgroup appuser && \
    chown -R appuser:appgroup /app

# ✅ Cambiar al usuario sin privilegios antes de lanzar el proceso
USER appuser

EXPOSE 5000
CMD ["python3", "-m", "gunicorn", "--bind", "0.0.0.0:5000",
     "--workers", "1", "--timeout", "60", "app:app"]