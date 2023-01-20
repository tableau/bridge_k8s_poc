#!/usr/bin/env bash
set -o errexit; set -o errtrace; set -o nounset; set -o pipefail; set -o xtrace;
ECR_HOSTNAME="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
ECR_REPO=$REPOSITORY_NAME
ECR_IMAGE_TAG="$APP_VERSION-$CODEBUILD_BUILD_NUMBER"
docker build \
  --tag "$ECR_HOSTNAME/$ECR_REPO:$ECR_IMAGE_TAG" \
  --progress=plain \
  ./
# push image to Elastic Container Registry
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_HOSTNAME"
docker push "$ECR_HOSTNAME/$ECR_REPO:$ECR_IMAGE_TAG"
