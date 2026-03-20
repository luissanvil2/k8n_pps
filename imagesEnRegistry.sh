#!/bin/bash
set -e  # detener si cualquier comando falla

echo "==> Levantando registry local..."
if docker ps -a --format '{{.Names}}' | grep -q "^registry$"; then
  docker start registry 2>/dev/null || true
  echo "    El registry ya existía, arrancado."
else
  docker run -d --name registry --restart=always -p 5000:5000 registry:2
  echo "    Registry creado."
fi

echo "==> Construyendo imágenes..."
docker build -t localhost:5000/counter-web:1.0   ./web
docker build -t localhost:5000/counter-nginx:1.0 ./nginx

echo "==> Subiendo imágenes al registry..."
docker push localhost:5000/counter-web:1.0
docker push localhost:5000/counter-nginx:1.0

echo ""
echo "✅ Listo. Imágenes disponibles en el registry local."
echo "   Puedes seguir ejecutando 'docker compose up' con normalidad."