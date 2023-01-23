#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

: "${REPOSITORY_NAME:?REPOSITORY_NAME is required}"

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile saml)
AWS_ORGANIZATION_ID=$(aws organizations describe-organization --query Organization.Id --output text --profile saml)

cp template/codepipeline.yaml codepipeline_new.yaml
sed -i.bak "s|\$AWS_ACCOUNT_ID|$AWS_ACCOUNT_ID|" codepipeline_new.yaml
sed -i.bak "s|\$AWS_ORGANIZATION_ID|$AWS_ORGANIZATION_ID|" codepipeline_new.yaml

aws cloudformation create-stack \
    --stack-name "$(echo "codepipeline-$REPOSITORY_NAME" | sed -r 's/_/-/g')" \
    --template-body file://codepipeline_new.yaml \
    --parameters ParameterKey=RepositoryName,ParameterValue="$REPOSITORY_NAME" \
                 ParameterKey=S3Key,ParameterValue="codepipeline/repositories/$REPOSITORY_NAME" \
                 ParameterKey=SecurityGroupIds,ParameterValue=sg-0cb844360303ffabd \
                 ParameterKey=Subnets,ParameterValue=subnet-067a0adb670ee49c8 \
                 ParameterKey=VpcId,ParameterValue=vpc-0cef6ccc5c7c8318e \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile saml
