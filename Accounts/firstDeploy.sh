#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="deployment_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    local message="$1"
    local level="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${level}[${timestamp}] ${message}${NC}"
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

# Function to run forge command and check result
run_forge_command() {
    local command="$1"
    local description="$2"
    
    log_message "Starting: ${description}" "${YELLOW}"
    
    if eval "$command"; then
        log_message "Success: ${description}" "${GREEN}"
        return 0
    else
        log_message "Failed: ${description}" "${RED}"
        return 1
    fi
}

# Check if required parameters are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    log_message "Usage: $0 <rpc_url> <private_key>" "${RED}"
    exit 1
fi

RPC_URL="$1"
PRIVATE_KEY="$2"

# Start deployment process
log_message "Starting deployment process..." "${YELLOW}"
log_message "RPC URL: $RPC_URL" "${YELLOW}"
log_message "Using private key: ${PRIVATE_KEY:0:6}..." "${YELLOW}"

# Preview Addresses
run_forge_command "forge script script/preview_deployed_addresses.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Preview Addresses"

# Deploy Implementation Manager
run_forge_command "forge script script/deploy/deployImplementationManagerDeterministic.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Deploy Implementation Manager"

# Deploy Factory Staker
run_forge_command "forge script script/deploy/deployFactoryStakerDeterministic.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Deploy Factory Staker"

# Deploy Account Factory
run_forge_command "forge script script/deploy/deployAccountFactoryDeterministic.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Deploy Account Factory"

# Deploy Kernel
run_forge_command "forge script script/deploy/deployKernel.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Deploy Kernel"

# Deploy Proxy Upgrader
run_forge_command "forge script script/deploy/deployProxyUpgrader.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Deploy Proxy Upgrader"

# Initialize and Register
run_forge_command "forge script script/postDeployment.s.sol --broadcast --rpc-url $RPC_URL --private-key $PRIVATE_KEY" "Initialize and Register"

# Check if any command failed
if [ $? -eq 0 ]; then
    log_message "All deployments completed successfully!" "${GREEN}"
    log_message "Log file: $LOG_FILE" "${GREEN}"
    exit 0
else
    log_message "Deployment process completed with some errors. Check the log file for details." "${RED}"
    log_message "Log file: $LOG_FILE" "${RED}"
    exit 1
fi