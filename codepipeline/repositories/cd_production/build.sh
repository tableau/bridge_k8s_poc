#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/AWSCodeBuildEksDescribeRole-${AWS_REGION}-${REPOSITORY_NAME}"
set +x
CREDENTIALS=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name codebuild-kubectl --duration-seconds 900)
export AWS_ACCESS_KEY_ID="$(echo "$CREDENTIALS" | jq -r '.Credentials.AccessKeyId')"
export AWS_SECRET_ACCESS_KEY="$(echo "$CREDENTIALS" | jq -r '.Credentials.SecretAccessKey')"
export AWS_SESSION_TOKEN="$(echo "$CREDENTIALS" | jq -r '.Credentials.SessionToken')"
export AWS_EXPIRATION=$(echo "$CREDENTIALS" | jq -r '.Credentials.Expiration')
set -x

aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
kubectl apply -k ./apps/production
sleep 5
kubectl get pods -n tableau
