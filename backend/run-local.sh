#!/bin/bash

# Simon Backend Local Development Script

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simon Backend - Local Development${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    cp .env.example .env
    echo "Please edit .env with your configuration"
fi

# Check if authenticated
if ! gcloud auth application-default print-access-token &> /dev/null; then
    echo -e "${YELLOW}Setting up Google Cloud authentication...${NC}"
    gcloud auth application-default login
fi

# Set project
echo -e "${YELLOW}Setting GCP project to simon-7a833...${NC}"
gcloud config set project simon-7a833

# Download dependencies
echo -e "${YELLOW}Downloading Go dependencies...${NC}"
go mod download

# Run the server
echo -e "${GREEN}Starting server on http://localhost:8080${NC}"
echo ""
go run cmd/api/main.go
