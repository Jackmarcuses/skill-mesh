# SkillMesh API — Production Dockerfile
# Compatible with Heroku, Koyeb, Render, and local Docker
# Uses asyncpg (pure Python async driver — no libpq needed)

# ─── Stage 1: Build dependencies ──────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# gcc needed to compile some packages (e.g. cryptography)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# ─── Stage 2: Production image ────────────────────────────────────────────────
FROM python:3.12-slim AS production

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application code
COPY . .

# Non-root user for security
RUN addgroup --system skillmesh \
    && adduser --system --ingroup skillmesh --no-create-home skillmesh
USER skillmesh

EXPOSE 8000

# Health check — used by Koyeb, Render, Docker Compose
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/v1/health')" || exit 1

# PORT defaults to 8000 — Heroku/Koyeb/Render override via environment
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 2"]
