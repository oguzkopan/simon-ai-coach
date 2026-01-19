#!/bin/bash

# Simon Backend Deployment Script
# Deploys to Google Cloud Run with minimum resource requirements

set -e  # Exit on error

# Configuration
PROJECT_ID="simon-7a833"
PROJECT_NUMBER="84366855987"
SERVICE_NAME="simon-api"
REGION="us-central1"
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Simon Backend Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Project ID: ${PROJECT_ID}"
echo "Project Number: ${PROJECT_NUMBER}"
echo "Service: ${SERVICE_NAME}"
echo "Region: ${REGION}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Set the project
echo -e "${YELLOW}Setting GCP project...${NC}"
gcloud config set project ${PROJECT_ID}

# Enable required APIs
echo -e "${YELLOW}Enabling required APIs...${NC}"
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    firestore.googleapis.com \
    aiplatform.googleapis.com \
    --project=${PROJECT_ID}

# Build and push the container image
echo -e "${YELLOW}Building container image...${NC}"
gcloud builds submit \
    --tag ${IMAGE_NAME} \
    --project=${PROJECT_ID} \
    .

# Deploy to Cloud Run with MINIMUM resources for cost optimization
echo -e "${YELLOW}Deploying to Cloud Run...${NC}"
gcloud run deploy ${SERVICE_NAME} \
    --image ${IMAGE_NAME} \
    --platform managed \
    --region ${REGION} \
    --project ${PROJECT_ID} \
    --allow-unauthenticated \
    --set-env-vars "GCP_PROJECT=${PROJECT_ID},GCP_LOCATION=${REGION},GEMINI_MODEL_ID=gemini-3-flash-preview,GEMINI_MODEL_ID_PRO=gemini-3-flash-preview,GEMINI_MAX_TOKENS=8192,GEMINI_TEMPERATURE=0.7,FREE_TIER_MOMENTS_PER_DAY=3,FREE_TIER_MESSAGES_PER_SESSION=10,PRO_TIER_MESSAGES_PER_SESSION=100" \
    --memory 512i \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --concurrency 80 \
    --timeout 300 \
    --cpu-throttling \
    --no-cpu-boost \
    --execution-environment gen2

# Get the service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
    --platform managed \
    --region ${REGION} \
    --project ${PROJECT_ID} \
    --format 'value(status.url)')

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Service URL: ${GREEN}${SERVICE_URL}${NC}"
echo ""
echo "Test the deployment:"
echo -e "  ${YELLOW}curl ${SERVICE_URL}/healthz${NC}"
echo ""
echo "Cost Optimization Settings Applied:"
echo "  • Memory: 256Mi (minimum)"
echo "  • CPU: 1 (minimum)"
echo "  • Min instances: 0 (scales to zero)"
echo "  • Max instances: 10"
echo "  • CPU throttling: enabled"
echo "  • CPU boost: disabled"
echo "  • Execution environment: gen2 (more efficient)"
echo ""
echo -e "${YELLOW}Update your iOS app with this URL:${NC}"
echo "  SimonAPIClient.swift -> baseURL = \"${SERVICE_URL}\""
echo ""
