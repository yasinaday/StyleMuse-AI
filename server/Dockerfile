FROM python:3.12-slim
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && useradd -u 10001 -M -s /usr/sbin/nologin appuser
COPY app.py store.py providers.py ./
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 CMD python -c "import urllib.request,os; r=urllib.request.urlopen(urllib.request.Request('http://127.0.0.1:8080/api/health',headers={'Authorization':'Bearer '+os.environ.get('STYLEMUSE_ACCESS_TOKEN','')}),timeout=3); assert r.status==200"
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1", "--no-access-log", "--no-proxy-headers"]
