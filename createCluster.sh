#!/bin/bash
set -e

# ── 1. Instalar kind si no está ────────────────────────────────
echo "==> Verificando kind..."
if ! command -v kind &>/dev/null; then
  echo "    Instalando kind..."
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
  echo "    kind instalado."
else
  echo "    kind ya está instalado."
fi

# ── 2. Instalar kubectl si no está ─────────────────────────────
echo "==> Verificando kubectl..."
if ! command -v kubectl &>/dev/null; then
  echo "    Instalando kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/kubectl
  echo "    kubectl instalado."
else
  echo "    kubectl ya está instalado."
fi

# ── 3. Generar kind-config.yaml ─────────────────────────────────
echo "==> Generando kind-config.yaml..."
cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://registry:5000"]
EOF

# ── 4. Crear el clúster ─────────────────────────────────────────
echo "==> Creando clúster kind..."
if kind get clusters 2>/dev/null | grep -q "^kind$"; then
  echo "    El clúster 'kind' ya existe, omitiendo creación."
else
  kind create cluster --config kind-config.yaml
fi

# ── 5. Conectar el registry a la red de kind ────────────────────
echo "==> Conectando registry a la red de kind..."
docker network connect kind registry 2>/dev/null || echo "    Ya estaba conectado."

# ── 6. Instalar metrics-server si no está ───────────────────────
echo "==> Instalando metrics-server..."
if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "    metrics-server ya existe, omitiendo instalación."
else
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

  # ── 7. Configurar metrics-server para kind y resolución rápida ──
  echo "==> Configurando metrics-server..."
  kubectl patch deployment metrics-server -n kube-system \
    --type='json' \
    -p='[
      {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
      {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--metric-resolution=5s"}
    ]'

  echo "    Esperando a que metrics-server esté listo..."
  kubectl rollout status deployment/metrics-server \
    -n kube-system --timeout=90s
fi

# ── 8. Configurar HPA sync period a 10s ─────────────────────────
echo "==> Configurando HPA sync period..."
if docker exec kind-control-plane grep -q "horizontal-pod-autoscaler-sync-period" \
  /etc/kubernetes/manifests/kube-controller-manager.yaml; then
  # Con esto modificamos la tasa de muestreo por defecto de 15s a 10s.
  docker exec kind-control-plane sed -i \
    's/--horizontal-pod-autoscaler-sync-period=.*/--horizontal-pod-autoscaler-sync-period=10s/' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
  echo "    Parámetro actualizado."
else
  docker exec kind-control-plane sed -i \
    '/- kube-controller-manager/a\    - --horizontal-pod-autoscaler-sync-period=10s' \
    /etc/kubernetes/manifests/kube-controller-manager.yaml
  echo "    Parámetro añadido."
fi
echo "    Esperando reinicio del controller manager..."
sleep 15

echo ""
echo "✅ Clúster listo."
kubectl get nodes