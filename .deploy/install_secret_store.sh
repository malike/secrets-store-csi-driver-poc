#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'No namespace supplied. Exiting...'
    exit 1
fi
echo "Installing csi-secrets-store in namespcae: $1"
kubectl create namespace $1 --dry-run=client -o yaml | kubectl apply -f -
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace $1
echo "Installation complete."
