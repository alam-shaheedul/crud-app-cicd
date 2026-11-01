#!/bin/bash

# detect-changes.sh - Detects which CRUD services have changed

set -e

declare -A SERVICE_MAP=(
    ["frontend"]="frontend"
    ["backend"]="backend"
    ["docker-compose.yml"]="all"
    ["nginx/nginx.conf"]="frontend"
    [".env"]="all"
    ["database"]="all"
)

CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git ls-files)

echo "Changed files:"
echo "$CHANGED_FILES"
echo ""

SERVICES_TO_DEPLOY=""
DEPLOY_ALL=false

while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi

    echo "Analyzing: $file"

    for service_path in "${!SERVICE_MAP[@]}"; do
        if [[ "$file" == "$service_path"* ]] || [[ "$file" == "$service_path" ]]; then
            services="${SERVICE_MAP[$service_path]}"

            if [ "$services" = "all" ]; then
                DEPLOY_ALL=true
                break
            else
                for service in $services; do
                    if [[ ! " $SERVICES_TO_DEPLOY " =~ " $service " ]]; then
                        SERVICES_TO_DEPLOY="$SERVICES_TO_DEPLOY $service"
                    fi
                done
            fi
            break
        fi
    done
done <<< "$CHANGED_FILES"

if [ "$DEPLOY_ALL" = true ]; then
    echo "DEPLOY_ALL=true" >> "$GITHUB_OUTPUT"
    echo "SERVICES=" >> "$GITHUB_OUTPUT"
    echo "Deploying all services due to infrastructure changes"
else
    SERVICES_TO_DEPLOY=$(echo "$SERVICES_TO_DEPLOY" | xargs)
    echo "DEPLOY_ALL=false" >> "$GITHUB_OUTPUT"
    echo "SERVICES=$SERVICES_TO_DEPLOY" >> "$GITHUB_OUTPUT"
    echo "Services to deploy: $SERVICES_TO_DEPLOY"
fi
