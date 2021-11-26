#!/bin/bash
echo "This script create deployments for cluster"
echo "Configuring parameter store access..."
REGION=eu-central-1
CLUSTERNAME=Task11-EKS
POLICY_ARN=$(aws --region "$REGION" --query Policy.Arn --output text iam create-policy --policy-name nginx-parameter-deployment-policy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [ {
        "Effect": "Allow",
        "Action": ["ssm:GetParameter", "ssm:GetParameters"],
        "Resource": ["arn:aws:ssm:eu-central-1:316986010667:parameter/MyParameter"]
    } ]
}')
eksctl utils associate-iam-oidc-provider --region="$REGION" --cluster="$CLUSTERNAME" --approve
eksctl create iamserviceaccount --name nginx-deployment-sa --region="$REGION" --cluster "$CLUSTERNAME" --attach-policy-arn "$POLICY_ARN" --approve --override-existing-serviceaccounts
echo "Create deployment, hpa, etc.."
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/SecretProviderClass.yaml
echo "SPC Created!"
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/Deployment.yaml
echo "Deployment created"
kubectl create -f /home/ubuntu/PlaysDev-Final/Cluster/HPA.yaml
echo "HPA created"
