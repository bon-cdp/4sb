#!/bin/bash
# 4sb.io - Warm Pool Manager
# Keeps a pool of pre-warmed VMs ready for instant assignment
#
# Run this as a daemon or cron job

set -e

PROJECT_ID="${PROJECT_ID:-forsmallbusiness}"
ZONE="${ZONE:-us-central1-a}"
GROUP_NAME="4sb-terminal-group"
MIN_WARM="${MIN_WARM:-2}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check Redis connectivity
check_redis() {
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping >/dev/null 2>&1
}

# Get current warm pool size
get_warm_count() {
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SCARD warm_pool 2>/dev/null || echo 0
}

# Get list of running instances
get_running_instances() {
    gcloud compute instance-groups managed list-instances "$GROUP_NAME" \
        --zone="$ZONE" \
        --filter="status=RUNNING" \
        --format="value(instance)" 2>/dev/null
}

# Add instance to warm pool
add_to_pool() {
    local instance=$1
    local ip=$(gcloud compute instances describe "$instance" \
        --zone="$ZONE" \
        --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)

    if [ -n "$ip" ]; then
        redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" SADD warm_pool "$instance:$ip" >/dev/null
        log "Added $instance ($ip) to warm pool"
    fi
}

# Main loop
main() {
    log "=== 4sb Warm Pool Manager Started ==="
    log "Min warm instances: $MIN_WARM"

    while true; do
        if ! check_redis; then
            log "WARNING: Redis not available, skipping cycle"
            sleep 30
            continue
        fi

        warm_count=$(get_warm_count)
        log "Warm pool size: $warm_count / $MIN_WARM"

        if [ "$warm_count" -lt "$MIN_WARM" ]; then
            log "Pool below minimum, checking for available instances..."

            # Get running instances not in pool
            for instance in $(get_running_instances); do
                # Check if already in pool or assigned
                in_pool=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
                    SISMEMBER warm_pool "$instance:*" 2>/dev/null || echo 0)
                assigned=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
                    GET "assigned:$instance" 2>/dev/null)

                if [ "$in_pool" = "0" ] && [ -z "$assigned" ]; then
                    add_to_pool "$instance"
                    warm_count=$((warm_count + 1))

                    if [ "$warm_count" -ge "$MIN_WARM" ]; then
                        break
                    fi
                fi
            done

            # If still not enough, scale up the instance group
            if [ "$warm_count" -lt "$MIN_WARM" ]; then
                current_size=$(gcloud compute instance-groups managed describe "$GROUP_NAME" \
                    --zone="$ZONE" \
                    --format="value(targetSize)" 2>/dev/null || echo 1)
                new_size=$((current_size + MIN_WARM - warm_count))

                log "Scaling instance group from $current_size to $new_size"
                gcloud compute instance-groups managed resize "$GROUP_NAME" \
                    --zone="$ZONE" \
                    --size="$new_size" \
                    --quiet 2>/dev/null || true
            fi
        fi

        sleep 30
    done
}

# Run with: ./pool-manager.sh
# Or: ./pool-manager.sh daemon (for background)
if [ "$1" = "daemon" ]; then
    main >> /var/log/4sb-pool-manager.log 2>&1 &
    echo $! > /var/run/4sb-pool-manager.pid
    log "Started as daemon, PID: $(cat /var/run/4sb-pool-manager.pid)"
else
    main
fi
