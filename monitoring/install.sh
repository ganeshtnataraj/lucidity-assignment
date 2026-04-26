#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values prometheus-values.yaml \
  --timeout 10m

echo ""
echo "Grafana LoadBalancer IP (may take a moment):"
kubectl get svc -n "$NAMESPACE" kube-prometheus-stack-grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
echo ""
echo "Default credentials: admin / admin"
