#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile saml)
AWS_ORGANIZATION_ID=$(aws organizations describe-organization --query Organization.Id --output text --profile saml)

cp template/codepipeline.yaml .
sed -i.bak "s|\$AWS_ACCOUNT_ID|$AWS_ACCOUNT_ID|" codepipeline.yaml
sed -i.bak "s|\$AWS_ORGANIZATION_ID|$AWS_ORGANIZATION_ID|" codepipeline.yaml

# run this section for each service name (e.g. tableau_bridge, pat_client)
service_name=tableau_bridge
aws_service_name=$(sed -r 's/_/-/g' <<< "$service_name")
aws cloudformation create-stack \
    --stack-name "codepipeline-$aws_service_name" \
    --template-body file://codepipeline.yaml \
    --parameters ParameterKey=RepositoryName,ParameterValue=$service_name \
                 ParameterKey=SecurityGroupIds,ParameterValue=sg-0cb844360303ffabd \
                 ParameterKey=Subnets,ParameterValue=subnet-067a0adb670ee49c8 \
                 ParameterKey=VpcId,ParameterValue=vpc-0cef6ccc5c7c8318e \
    --capabilities CAPABILITY_NAMED_IAM \
    --profile saml
