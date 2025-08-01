#!/bin/bash
# Container Validation Script for Wiz Technical Exercise
# This script demonstrates how to validate the wizexercise.txt file exists in the container

echo "=== Wiz Technical Exercise Container Validation ==="
echo ""

# Get the ACR login server
ACR_NAME="acrwizappnonprod001"
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "1. Building and pushing container image to ACR..."
echo "   ACR: $ACR_LOGIN_SERVER"
echo ""

# Login to ACR (requires Azure CLI and proper permissions)
echo "az acr login --name $ACR_NAME"
echo ""

# Build and tag the image
echo "docker build -t wizapp:latest ."
echo "docker tag wizapp:latest $ACR_LOGIN_SERVER/wizapp:latest"
echo ""

# Push to ACR
echo "docker push $ACR_LOGIN_SERVER/wizapp:latest"
echo ""

echo "2. Validating wizexercise.txt in built image..."
echo "   Running container to check file existence:"
echo ""

# Test locally first
echo "docker run --rm $ACR_LOGIN_SERVER/wizapp:latest sh -c 'ls -la /app/wizexercise.txt && cat /app/wizexercise.txt'"
echo ""

echo "3. Validating in running Kubernetes pod..."
echo "   Getting pod name:"
echo "kubectl get pods -n wizapp -l app=wizapp"
echo ""

echo "   Checking file in running pod:"
echo "POD_NAME=\$(kubectl get pods -n wizapp -l app=wizapp -o jsonpath='{.items[0].metadata.name}')"
echo "kubectl exec -n wizapp \$POD_NAME -- ls -la /app/wizexercise.txt"
echo "kubectl exec -n wizapp \$POD_NAME -- cat /app/wizexercise.txt"
echo ""

echo "4. Demo commands for presentation:"
echo "   # Show application is running"
echo "   kubectl get pods -n wizapp"
echo "   kubectl get svc -n wizapp"
echo "   kubectl get ingress -n wizapp"
echo ""
echo "   # Show cluster-admin permissions"
echo "   kubectl auth can-i '*' '*' --as=system:serviceaccount:wizapp:wizapp-sa"
echo ""
echo "   # Show MongoDB connectivity"
echo "   kubectl logs -n wizapp deployment/wizapp-deployment | grep -i mongo"
echo ""

echo "=== End of Validation Script ===" 