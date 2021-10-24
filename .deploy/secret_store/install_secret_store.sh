#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'No namespace supplied. Exiting...'
    exit 1
fi

NAMESPACE=$1

echo "Installing csi-secrets-store in namespace: $NAMESPACE"
kubectl create ns $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver -n $NAMESPACE
kubectl wait --for=condition=Ready --timeout=120s pods --all -n $NAMESPACE
echo "Installation complete."
