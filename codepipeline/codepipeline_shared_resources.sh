#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

aws cloudformation create-stack \
    --stack-name codepipeline-shared-resources \
    --template-body file://template/codepipeline_shared_resources.yaml \
    --profile saml

aws cloudformation wait stack-create-complete \
    --stack-name codepipeline-shared-resources \
    --profile saml
