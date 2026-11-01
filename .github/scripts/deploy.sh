#!/bin/bash

set -e

APP_DIR="/opt/crud-app"
BRANCH="main"

cd "$APP_DIR"

echo "Fetching latest changes..."
git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service..."

    while [ "$attempt" -le "$max_attempts" ]; do
        if docker compose ps "$service" | grep -q "Up"; then
            echo "$service is running."
            return 0
        fi

        sleep 5
        attempt=$((attempt + 1))
    done

    echo "ERROR: $service failed to start."
    docker compose logs "$service"
    return 1
}

deploy_all() {
    echo "Deploying all services..."

    docker compose down
    docker compose pull || echo "No existing images available; building locally."
    docker compose up -d --build

    wait_for_service db
    wait_for_service redis
    wait_for_service backend
    wait_for_service frontend

    echo "All services deployed successfully."
}

deploy_service() {
    local service=$1

    echo "Deploying service: $service"

    docker compose up -d db redis
    wait_for_service db
    wait_for_service redis

    docker compose pull "$service" || echo "Building $service locally."
    docker compose up -d --build --no-deps "$service"

    wait_for_service "$service"
    echo "$service deployed successfully."
}

if [ "$1" = "all" ]; then
    deploy_all
else
    for service in $1; do
        deploy_service "$service"
    done
fi
