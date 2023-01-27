#!/usr/bin/env bash
set -o errexit; set -o nounset; set -o pipefail; set -o xtrace;

function help(){
    echo "USAGE: setup.sh -o <create or delete> -v <vpc name> -s <secret name> -c <cluster name> -r <AWS region>"
}

unset -v Operation
unset -v VPC_NAME
unset -v SECRET_ID
unset -v CLUSTER
unset -v REGION

PASSED_ARGS=$@
if [[ ${#PASSED_ARGS} -ne 0 ]]
then
    while getopts ":o:v:s:c:r:h" opt; do
    case "$opt" in
        o) Operation=$OPTARG ;;
        v) VPC_NAME=$OPTARG ;;
        s) SECRET_ID=$OPTARG ;;
        c) CLUSTER=$OPTARG ;;
        r) REGION=$OPTARG ;;
        h) help ;;
        :​) echo "argument missing for $opt" ;;
        \?) echo "Something is wrong" ;;
    esac
    done
else 
  help
  exit 1
fi
shift "$((OPTIND-1))"

if [ -z "$Operation" ] || [ -z "$VPC_NAME" ] || [ -z "$SECRET_ID" ] || [ -z "$CLUSTER" ] || [ -z "$REGION" ]; then
        echo 'Missing -h or -u or -s or -c or -r' >&2
        help
        exit 1
fi

SECRET_ARN=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ID" --query ARN --output text --profile saml)

# if service_role doesn't exists, create using steps at https://docs.aws.amazon.com/eks/latest/userguide/service_IAM_role.html#create-service-role
service_role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`eksClusterRole`].Arn' --output text  --profile saml)
if [[ $service_role_arn != arn* ]]; then
    service_role_arn=$(aws iam create-role \
        --role-name eksClusterRole \
        --assume-role-policy-document file://"cluster-trust-policy.json" \
        --query Role.Arn --output text --profile saml)
    sleep 10
    aws iam attach-role-policy \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
        --role-name eksClusterRole --profile saml

fi

echo "service_role_arn is $service_role_arn"

ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --profile saml)
cp pod-execution-role-trust-policy.json pod-execution-role-trust-policy_new.json
sed -i.bak -e "s|\$ACCOUNT_ID|$ACCOUNT_ID|" "pod-execution-role-trust-policy_new.json"

# if fargate execution pod role does not exists, create using steps at https://docs.aws.amazon.com/eks/latest/userguide/pod-execution-role.html
fargate_pod_execution_role_arn=$(aws iam list-roles --query 'Roles[?RoleName==`AmazonEKSFargatePodExecutionRole`].Arn' --output text  --profile saml)
if [[ $fargate_pod_execution_role_arn != arn* ]]; then
    fargate_pod_execution_role_arn=$(aws iam create-role \
        --role-name AmazonEKSFargatePodExecutionRole \
        --assume-role-policy-document file://"pod-execution-role-trust-policy_new.json" \
        --query Role.Arn --output text --profile saml)
    aws iam attach-role-policy \
        --policy-arn arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy \
        --role-name AmazonEKSFargatePodExecutionRole --profile saml
fi

echo "fargate_pod_execution_role_arn is $fargate_pod_execution_role_arn"

if [ "$Operation" = "delete" ]; then
    eksctl delete cluster -f cluster_new.yaml --profile saml
    aws cloudformation delete-stack --stack-name "$VPC_NAME" --profile saml
    aws cloudformation wait stack-delete-complete --stack-name "$VPC_NAME" --profile saml
    exit 1
else 
    aws cloudformation create-stack \
    --stack-name "$VPC_NAME" \
    --template-body file://"codebuild-vpc-cfn.yaml" \
    --parameters ParameterKey=EnvironmentName,ParameterValue="$VPC_NAME" \
    --profile saml
    aws cloudformation wait stack-create-complete --stack-name "$VPC_NAME" --profile saml

    echo "$VPC_NAME creation completed"

    vpc_id=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='$VPC_NAME'][].Outputs[?OutputKey=='VPC'].OutputValue" --region "$REGION" --output text --profile saml)
    sg_id=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='$VPC_NAME'][].Outputs[?OutputKey=='NoIngressSecurityGroup'].OutputValue" --region "$REGION" --output text --profile saml)
    private_subnet1=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='$VPC_NAME'][].Outputs[?OutputKey=='PrivateSubnet1'].OutputValue" --region "$REGION" --output text --profile saml)
    private_subnet2=$(aws cloudformation describe-stacks --query "Stacks[?StackName=='$VPC_NAME'][].Outputs[?OutputKey=='PrivateSubnet2'].OutputValue" --region "$REGION" --output text --profile saml)

    cp cluster.yaml cluster_new.yaml

    sed -i.bak -e "s|\$private_subnet1|$private_subnet1|" "cluster_new.yaml"
    sed -i.bak -e "s|\$private_subnet2|$private_subnet2|" "cluster_new.yaml"
    sed -i.bak -e "s|\$vpc_id|$vpc_id|" "cluster_new.yaml"
    sed -i.bak -e "s|\$sg_id|$sg_id|" "cluster_new.yaml"
    sed -i.bak -e "s|\$fargate_pod_execution_role_arn|$fargate_pod_execution_role_arn|" "cluster_new.yaml"
    sed -i.bak -e "s|\$service_role_arn|$service_role_arn|" "cluster_new.yaml"
    sed -i.bak -e "s|\$REGION|$REGION|" "cluster_new.yaml"
    sed -i.bak -e "s|\$CLUSTER|$CLUSTER|" "cluster_new.yaml"
    sed -i.bak -e "s|\$SECRET_ARN|$SECRET_ARN|" "cluster_new.yaml"

    #########################
    # eks cluster creation script
    eksctl create cluster -f cluster_new.yaml --profile saml

    sleep 50

    echo "EKS cluster creation completed"
    
    kubectl create ns flux-system

    aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION" --profile saml

    helm repo add external-secrets https://charts.external-secrets.io

    sleep 50

    helm install external-secrets \
    external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true \
    --set webhook.port=9443 \
    --wait

    sleep 50

    echo "external-secrets installed"
    cp externalsecretstore.yaml externalsecretstore_new.yaml
    sed -i.bak -e "s|\$REGION|$REGION|" "externalsecretstore_new.yaml"

    kubectl apply -f externalsecretstore_new.yaml

    sleep 50
    cp externalsecret.yaml externalsecret_new.yaml
    sed -i.bak -e "s|\$SECRET_ID|$SECRET_ID|" "externalsecret_new.yaml"

    kubectl apply -f externalsecret_new.yaml

    sleep 50

    # To deploy fluent-bit sidecar to aggregate per container logs into CloudWatch
    cp fluent-bit-bridge-configmap.yaml fluent-bit-bridge-configmap_new.yaml
    sed -i.bak -e "s|\$CLUSTER|$CLUSTER|" "fluent-bit-bridge-configmap_new.yaml"
    sed -i.bak -e "s|\$REGION|$REGION|" "fluent-bit-bridge-configmap_new.yaml"
    kubectl apply -f fluent-bit-bridge-configmap_new.yaml
    
    # To deploy ADOT metrics collector for Container Insight 
    cp adot.yaml adot_new.yaml
    sed -i.bak -e "s|\$CLUSTER|$CLUSTER|" "adot_new.yaml"
    sed -i.bak -e "s|\$REGION|$REGION|" "adot_new.yaml"
    kubectl apply -f adot_new.yaml
    
    #Bridge container deployment is done via CI/CD pipeline
    #echo "bridge_deployment started"

    #kubectl apply -f bridge_deployment.yaml
    
    exit 1
fi




