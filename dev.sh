#!/bin/bash

# Define colors for log prefixes
COLOR_USER="\033[32m"  # Green for user service
COLOR_POST="\033[1;34m"  # Blue for post service
COLOR_GRAPHQL="\033[35m"  # Magenta for GraphQL server
COLOR_RESET="\033[0m"  # Reset color

# Temporary log files
USER_LOG="/tmp/user_service.log"
POST_LOG="/tmp/post_service.log"

# Function to check if a gRPC service is healthy
check_grpc_service() {
    local service=$1
    local port=$2
    local retries=5
    local wait=2

    for ((i=0; i<retries; i++)); do
        # Suppress error output by redirecting to /dev/null
        if grpcurl -plaintext "localhost:${port}" grpc.health.v1.Health/Check 2>/dev/null | grep -q "SERVING"; then
            return 0
        fi

        sleep $wait
    done

    return 1
}

# Function to display a loading message
show_loader() {
    local delay=0.5
    local spin='/-\|'
    echo -n "Waiting for services to start... "

    while true; do
        for i in $(seq 0 3); do
            echo -ne "\rWaiting for services to start... ${spin:i:1}  "
            sleep $delay
        done

        # Check if services are healthy; exit the loop if they are
        if check_grpc_service "User Service" 50051 && check_grpc_service "Post Service" 50052; then
            echo -ne "\rAll services are healthy. Starting logs...  \n"
            break
        fi
    done
}

# Function to stop existing services
stop_service() {
    local pid=$1
    if kill $pid 2>/dev/null; then
        wait $pid 2>/dev/null
        echo -e "${COLOR_RESET}Stopped service with PID $pid.${COLOR_RESET}"
    else
        echo -e "${COLOR_RESET}No service running with PID $pid.${COLOR_RESET}"
    fi
}

# Check for existing processes on the service ports and stop them
if lsof -Pi :50051 -sTCP:LISTEN -t >/dev/null; then
    echo -e "${COLOR_RESET}Stopping existing User Service...${COLOR_RESET}"
    USER_SERVICE_PID=$(lsof -t -i:50051)
    stop_service $USER_SERVICE_PID
fi

if lsof -Pi :50052 -sTCP:LISTEN -t >/dev/null; then
    echo -e "${COLOR_RESET}Stopping existing Post Service...${COLOR_RESET}"
    POST_SERVICE_PID=$(lsof -t -i:50052)
    stop_service $POST_SERVICE_PID
fi

# Start the services in the background and redirect output to temporary log files
go run ./user-service/main.go > "$USER_LOG" 2>&1 &
USER_SERVICE_PID=$!

go run ./post-service/main.go > "$POST_LOG" 2>&1 &
POST_SERVICE_PID=$!

# Show the loader while checking the health of services
show_loader

# Display logs for the User Service
tail -f "$USER_LOG" | while IFS= read -r line; do
    echo -e "${COLOR_USER}[users-api]${COLOR_RESET} $line"
done &

# Display logs for the Post Service
tail -f "$POST_LOG" | while IFS= read -r line; do
    echo -e "${COLOR_POST}[posts-api]${COLOR_RESET} $line"
done &

# Start the GraphQL server
ls ./graph/*.graphql | entr -r tailcall start ./graph/graph.graphql 2>&1 | while IFS= read -r line; do
    echo -e "${COLOR_GRAPHQL}[graph-bff]${COLOR_RESET} $line"
done &
GRAPHQL_SERVER_PID=$!

# Function to clean up on exit
cleanup() {
    echo -e "${COLOR_RESET}Stopping services...${COLOR_RESET}"
    stop_service $USER_SERVICE_PID
    stop_service $POST_SERVICE_PID
    kill $GRAPHQL_SERVER_PID 2>/dev/null || true
    # Remove temporary log files
    rm -f "$USER_LOG" "$POST_LOG"
    exit
}

# Set the trap to call cleanup on SIGINT
trap cleanup SIGINT

# Wait for all services to finish
wait $USER_SERVICE_PID
wait $POST_SERVICE_PID
wait $GRAPHQL_SERVER_PID
