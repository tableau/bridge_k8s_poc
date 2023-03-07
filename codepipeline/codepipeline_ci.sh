#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

: "${REPOSITORY_NAME:?REPOSITORY_NAME is required}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile saml)
AWS_ORGANIZATION_ID=$(aws organizations describe-organization --query Organization.Id --output text --profile saml)
AWS_REGION=$(aws configure get region --profile saml)
S3_BUCKET="tableau-$AWS_REGION-$AWS_ACCOUNT_ID"
S3_KEY="repositories/ci/$REPOSITORY_NAME.zip"
STACK_NAME="$(echo "ci-$REPOSITORY_NAME" | sed -r 's/_/-/g')"

pushd "repositories/ci/$REPOSITORY_NAME"
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
                 ParameterKey=SecurityGroupIds,ParameterValue=sg-07794cbbf72b3c1f4 \
                 ParameterKey=Subnets,ParameterValue=subnet-0cd775f4dfdfc4484 \
                 ParameterKey=VpcId,ParameterValue=vpc-00db17af1656997cd \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile saml

aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --profile saml
