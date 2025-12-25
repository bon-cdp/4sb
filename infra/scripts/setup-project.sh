#!/bin/bash
# 4sb.io - GCloud Project Setup
# Run this once to configure your project

set -e

PROJECT_ID="${PROJECT_ID:-forsmallbusiness}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"

echo "=== 4sb.io GCloud Setup ==="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Set project
gcloud config set project "$PROJECT_ID"
gcloud config set compute/region "$REGION"
gcloud config set compute/zone "$ZONE"

echo ">>> Enabling required APIs..."
gcloud services enable \
    compute.googleapis.com \
    run.googleapis.com \
    containerregistry.googleapis.com \
    redis.googleapis.com \
    file.googleapis.com \
    cloudbuild.googleapis.com

echo ">>> Creating firewall rules..."
# Allow WebSocket traffic
gcloud compute firewall-rules create allow-4sb-websocket \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:8080 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=4sb-terminal \
    2>/dev/null || echo "Firewall rule already exists"

# Allow health checks
gcloud compute firewall-rules create allow-4sb-health \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:8080 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --target-tags=4sb-terminal \
    2>/dev/null || echo "Health check firewall rule already exists"

echo ">>> Creating static IP for load balancer..."
gcloud compute addresses create 4sb-terminal-ip \
    --global \
    2>/dev/null || echo "Static IP already exists"

IP=$(gcloud compute addresses describe 4sb-terminal-ip --global --format='get(address)' 2>/dev/null || echo "pending")
echo "Static IP: $IP"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Run ./create-vm-template.sh to create the VM template"
echo "2. Run ./deploy.sh to deploy the terminal bridge"
echo ""
