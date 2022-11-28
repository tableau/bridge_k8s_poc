#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

# variables
TABLEAU_BRIDGE_RPM=$(basename "$TABLEAU_BRIDGE_RPM_URL")
TABLEAU_BRIDGE_SRC=$(basename "$TABLEAU_BRIDGE_SRC_URL")
TARGET_REPO=$SOURCE_REPO/target
ECR_HOSTNAME="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
ECR_REPO=$REPOSITORY_NAME
ECR_IMAGE_TAG=$(echo "$TABLEAU_BRIDGE_RPM-$CODEBUILD_BUILD_NUMBER" | sed -e 's/tableau-bridge-//' | sed -e 's/.x86_64.rpm//')

# download build script from gitrepo
curl --location --output ./$TABLEAU_BRIDGE_SRC "$TABLEAU_BRIDGE_SRC_URL"
tar -xvf $TABLEAU_BRIDGE_SRC
# modify it to get the below value from the $TABLEAU_BRIDGE_RPM_URL
mv bridge-test*/* .
chmod 755 ./build/build.sh

# download tableau bridge
curl --location --output "./build/$TABLEAU_BRIDGE_RPM" "$TABLEAU_BRIDGE_RPM_URL"

# update Dockerfile
#cp template/Dockerfile .
sed -i.bak "s|\$SOURCE_REPO|$TARGET_REPO|" Dockerfile
sed -i.bak "s|\$IMAGE_TAG|$IMAGE_TAG|" Dockerfile
sed -i.bak "s|\$USER|tableau|" Dockerfile

# build intermediate image with drivers
git clone https://github.com/tableau/container_image_builder.git
pushd container_image_builder
cat <<EOF > variables.sh
DRIVERS=$DRIVERS
OS_TYPE=$OS_TYPE
SOURCE_REPO=$SOURCE_REPO
IMAGE_TAG=$IMAGE_TAG
TARGET_REPO=$TARGET_REPO
USER=root
EOF
./download.sh
./build.sh
popd

# build image with tableau bridge
DOCKER_BUILDKIT=1 docker build \
  --build-arg TABLEAU_BRIDGE_RPM="$TABLEAU_BRIDGE_RPM" \
  --tag "$ECR_HOSTNAME/$ECR_REPO:$ECR_IMAGE_TAG" \
  --no-cache \
  --progress=plain \
  ./

# push image to Elastic Container Registry 
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_HOSTNAME"
docker push "$ECR_HOSTNAME/$ECR_REPO:$ECR_IMAGE_TAG"
