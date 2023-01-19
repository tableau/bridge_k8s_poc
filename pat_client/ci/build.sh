#!/usr/bin/env bash
set -o errexit; set -o errtrace; set -o nounset; set -o pipefail; set -o xtrace;
cd "$(dirname "$0")/.."
ECR=010465704656.dkr.ecr.us-west-2.amazonaws.com
APP_NAME="pat_client"
APP_VERSION="0.1.1"
IMAGE="$APP_NAME:$APP_VERSION"
ECR_IMAGE="$ECR/$IMAGE"
CONTAINER_NAME="build_$APP_NAME"
docker build \
  --tag "$IMAGE" \
  --progress=plain \
  ./
docker tag "$IMAGE" "$ECR_IMAGE"
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin "$ECR"
docker push "$ECR_IMAGE"
#CONTAINER_NAME="run_$APP_NAME"
#docker stop "$CONTAINER_NAME" ||:
#docker rm "$CONTAINER_NAME" ||:
#docker container run \
#  --detach \
#  --name "$CONTAINER_NAME" \
#  "$IMAGE" \
#  sleep infinity
#echo "docker exec -it $CONTAINER_NAME bash"
#kubectl create configmap pat-client --from-file=config --append-hash=true -n default ||:
#kubectl create secret generic pat-client --from-file=secret --append-hash=true -n default ||:
#kubectl create job --from=cronjob/pat-client pat-client-manual