#!/bin/bash

# Exit on error
set -e

# Check if required environment variables are set
if [ -z "$GCP_PROJECT_ID" ]; then
    echo "Error: GCP_PROJECT_ID environment variable is not set"
    exit 1
fi

if [ -z "$GCP_REGION" ]; then
    echo "Error: GCP_REGION environment variable is not set"
    exit 1
fi

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable appengine.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable firebase.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable storage.googleapis.com

# Create App Engine application
echo "Creating App Engine application..."
gcloud app create --region="$GCP_REGION" || true

# Create service account for deployment
echo "Creating service account for deployment..."
SA_NAME="flutter-deploy"
SA_EMAIL="$SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

gcloud iam service-accounts create "$SA_NAME" \
    --display-name="Flutter Deployment Service Account" || true

# Grant required permissions
echo "Granting required permissions..."
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/appengine.appAdmin"

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"

gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/cloudbuild.builds.editor"

# Create and download service account key
echo "Creating service account key..."
gcloud iam service-accounts keys create key.json \
    --iam-account="$SA_EMAIL"

echo "GCP setup completed successfully!"
echo "Please add the contents of key.json to your GitHub repository secrets as GCP_SA_KEY"