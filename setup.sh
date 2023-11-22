#!/bin/bash

# Pipeline name to be displayed.
export PIPELINE_NAME="psub-lite-to-bigquery-stream"

export REPOSITORY_NAME="psub-lite-to-bigquery-stream"

export VERSION="0.0.1"

export PROJECT_ID="" # My project ID

export CUSTOM_CONTAINER_NAME="psub-lite-to-bigquery-stream"

export SUFFIX="some-uniqueness-suffix" # ="m23t2rz"

export TEMPLATE_BUCKET="my-templates-${SUFFIX}"

gcloud storage buckets create gs://${TEMPLATE_BUCKET} --project=${PROJECT_ID}

export MAX_WORKERS=2

export MIN_WORKERS=1

gcloud artifacts repositories create ${REPOSITORY_NAME} --location=us-central1 --project=${PROJECT_ID} --repository-format=docker

export IMAGE_GCR_PATH="us-central1-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${CUSTOM_CONTAINER_NAME}:${VERSION}"

export TOPIC_NAME="trips"

gcloud pubsub lite-reservations create ${TOPIC_NAME} --project=${PROJECT_ID} --location=us-central1 --throughput-capacity=2

gcloud pubsub lite-topics create ${TOPIC_NAME} --project=${PROJECT_ID} --location=us-central1 --partitions=2 --per-partition-bytes=30GiB --throughput-reservation=${TOPIC_NAME}

#Create Pubsub Lite subscription.
gcloud pubsub lite-subscriptions create ${TOPIC_NAME} --location=us-central1 --topic=${TOPIC_NAME} --project=${PROJECT_ID}

export DATASET_NAME="analytics"

bq --location=us-central1 mk --dataset $PROJECT_ID:$DATASET_NAME

export TABLE_NAME="trips"

export SERVICE_ACCOUNT_NAME="psub-lite-to-bquery-sa"

gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME} --description="Service account for a dataproc worker" --display-name=${SERVICE_ACCOUNT_NAME} --project ${PROJECT_ID}


gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsublite.subscriber"


gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/pubsublite.viewer"


gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataEditor"


gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/dataflow.worker"

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"

# gcloud builds submit --project=${PROJECT_ID} --tag $IMAGE_GCR_PATH .

gcloud dataflow flex-template build gs://${TEMPLATE_BUCKET}/templates/${PIPELINE_NAME}/${PIPELINE_NAME}-${VERSION}.json \
    --image $IMAGE_GCR_PATH \
    --sdk-language "PYTHON" \
    --metadata-file "metadata.json" \
    --project $PROJECT_ID


export PSUB_SUBSCRIPTION_ID=projects/${PROJECT_ID}/locations/us-central1/subscriptions/${TOPIC_NAME}

gcloud dataflow flex-template run $PIPELINE_NAME \
    --template-file-gcs-location "gs://${TEMPLATE_BUCKET}/templates/${PIPELINE_NAME}/${PIPELINE_NAME}-${VERSION}.json" \
    --project $PROJECT_ID \
    --region="us-central1" \
    --max-workers $MAX_WORKERS \
    --num-workers $MIN_WORKERS \
    --parameters "subscription_id=${PSUB_SUBSCRIPTION_ID},dataset=${DATASET_NAME},table=${TABLE_NAME}" \
    --service-account-email "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"