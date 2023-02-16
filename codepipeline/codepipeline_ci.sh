#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

: "${REPOSITORY_NAME:?REPOSITORY_NAME is required}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile saml)
AWS_ORGANIZATION_ID=$(aws organizations describe-organization --query Organization.Id --output text --profile saml)
AWS_REGION=$(aws configure get region --profile saml)
S3_BUCKET="tableau-$AWS_REGION-$AWS_ACCOUNT_ID"
S3_KEY="repositories/$REPOSITORY_NAME.zip"
STACK_NAME="$(echo "codepipeline-$REPOSITORY_NAME" | sed -r 's/_/-/g')"

pushd "repositories/$REPOSITORY_NAME"
zip -r "$REPOSITORY_NAME.zip" .
aws s3 cp "$REPOSITORY_NAME.zip" "s3://$S3_BUCKET/$S3_KEY" --profile saml
popd

cp template/codepipeline_ci.yaml codepipeline_ci_new.yaml
sed -i.bak "s|\$AWS_ACCOUNT_ID|$AWS_ACCOUNT_ID|" codepipeline_ci_new.yaml
sed -i.bak "s|\$AWS_ORGANIZATION_ID|$AWS_ORGANIZATION_ID|" codepipeline_ci_new.yaml

aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://codepipeline_ci_new.yaml \
    --parameters ParameterKey=RepositoryName,ParameterValue="$REPOSITORY_NAME" \
                 ParameterKey=S3Bucket,ParameterValue="$S3_BUCKET" \
                 ParameterKey=S3Key,ParameterValue="$S3_KEY" \
                 ParameterKey=SecurityGroupIds,ParameterValue=sg-0cb844360303ffabd \
                 ParameterKey=Subnets,ParameterValue=subnet-067a0adb670ee49c8 \
                 ParameterKey=VpcId,ParameterValue=vpc-0cef6ccc5c7c8318e \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile saml

aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --profile saml
