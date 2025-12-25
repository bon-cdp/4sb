#!/bin/bash
# 4sb.io - Deploy Terminal Infrastructure
# Creates the managed instance group and load balancer

set -e

PROJECT_ID="${PROJECT_ID:-forsmallbusiness}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
TEMPLATE_NAME="fsb-terminal-template"
GROUP_NAME="fsb-terminal-group"
MIN_INSTANCES="${MIN_INSTANCES:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-5}"

echo "=== Deploying 4sb Terminal Infrastructure ==="
echo ""

# Create instance group
echo ">>> Creating managed instance group..."
gcloud compute instance-groups managed create "$GROUP_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --template="$TEMPLATE_NAME" \
    --size="$MIN_INSTANCES" \
    2>/dev/null || echo "Instance group already exists, updating..."

# Configure autoscaling
echo ">>> Configuring autoscaling..."
gcloud compute instance-groups managed set-autoscaling "$GROUP_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --min-num-replicas="$MIN_INSTANCES" \
    --max-num-replicas="$MAX_INSTANCES" \
    --target-cpu-utilization=0.6 \
    --cool-down-period=60 \
    2>/dev/null || true

# Create health check
echo ">>> Creating health check..."
gcloud compute health-checks create http fsb-health-check \
    --project="$PROJECT_ID" \
    --port=8080 \
    --request-path=/health \
    --check-interval=10s \
    --timeout=5s \
    --healthy-threshold=2 \
    --unhealthy-threshold=3 \
    2>/dev/null || echo "Health check already exists"

# Create backend service
echo ">>> Creating backend service..."
gcloud compute backend-services create fsb-backend \
    --project="$PROJECT_ID" \
    --protocol=HTTP \
    --health-checks=fsb-health-check \
    --global \
    2>/dev/null || echo "Backend service already exists"

# Add instance group to backend
gcloud compute backend-services add-backend fsb-backend \
    --project="$PROJECT_ID" \
    --instance-group="$GROUP_NAME" \
    --instance-group-zone="$ZONE" \
    --global \
    2>/dev/null || echo "Backend already configured"

echo ""
echo "=== Deployment Complete ==="
echo ""

# Show status
echo "Instance group status:"
gcloud compute instance-groups managed list-instances "$GROUP_NAME" \
    --zone="$ZONE" \
    --format="table(instance,status)"

echo ""
echo "To test, get an instance IP:"
echo "  gcloud compute instances list --filter='name~fsb' --format='get(networkInterfaces[0].accessConfigs[0].natIP)'"
echo ""
echo "Then: curl http://<IP>:8080/health"
