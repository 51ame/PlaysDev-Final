#!/bin/bash
echo "This script create deployments for cluster"
echo "Connecting to the cluster"
aws eks --region eu-central-1 update-kubeconfig --name Task11-EKS
echo "Connected"
echo "Install helm"
helm repo add secrets-store-csi-driver https://raw.githubusercontent.com/kubernetes-sigs/secrets-store-csi-driver/master/charts
helm install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
echo "Helm installed"
echo "Configuring parameter store access..."
REGION=eu-central-1
CLUSTERNAME=Task11-cluster
POLICY_ARN=$(aws --region "$REGION" --query Policy.Arn --output text iam create-policy --policy-name nginx-parameter-deployment-policy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["ssm:GetParameter", "ssm:GetParameters"],
        "Resource": ["arn:aws:ssm:eu-central-1:316986010667:parameter/MyParameter"]
    } ]
}')
echo "Success!"
echo "Try to login in ECR repo...."
aws ecr-public get-login-password --region us-east-1 | sudo docker login --username AWS --password-stdin public.ecr.aws/s4z6a2u8
echo "Login successfully!"
echo "Pull the docker image..."
sudo docker pull public.ecr.aws/s4z6a2u8/custom-ubuntu-nginx:latest
echo "Pull completed!"
eksctl utils associate-iam-oidc-provider --region="$REGION" --cluster="$CLUSTERNAME" --approve
eksctl create iamserviceaccount --name nginx-deployment-sa --region="$REGION" --cluster "$CLUSTERNAME" --attach-policy-arn "$POLICY_ARN" --approve --override-existing-serviceaccounts
echo "Create deployment, hpa, etc.."
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/SecretProviderClass.yaml
echo "SPC Created!"
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/Deployment.yaml
echo "Deployment created"
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/HPA.yaml
echo "HPA created"