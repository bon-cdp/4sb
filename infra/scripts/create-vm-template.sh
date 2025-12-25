#!/bin/bash
# 4sb.io - Create VM Instance Template
# Creates the template used for terminal VMs

set -e

PROJECT_ID="${PROJECT_ID:-forsmallbusiness}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
TEMPLATE_NAME="fsb-terminal-template"
MACHINE_TYPE="${MACHINE_TYPE:-e2-micro}"  # Cheap for dev, use t2a-standard-1 for prod

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Creating VM Template ==="
echo "Template: $TEMPLATE_NAME"
echo "Machine: $MACHINE_TYPE"
echo ""

# Delete old template if exists
gcloud compute instance-templates delete "$TEMPLATE_NAME" --quiet 2>/dev/null || true

# Create new template
gcloud compute instance-templates create "$TEMPLATE_NAME" \
    --project="$PROJECT_ID" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network=default,network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --tags=fsb-terminal \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=20GB \
    --boot-disk-type=pd-balanced \
    --metadata-from-file=startup-script="$SCRIPT_DIR/../templates/startup-script.sh"

echo ""
echo "=== Template Created ==="
echo ""
echo "Next: Run ./deploy.sh to create the instance group"
