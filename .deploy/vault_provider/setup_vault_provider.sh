#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo 'No namespace supplied. Exiting...'
    exit 1
fi

NAMESPACE=$1

echo "Setting up vault provider ..."
kubectl apply -f .deploy/vault_provider/vault-csi-provider.yaml -n $NAMESPACE
kubectl wait --for=condition=Ready --timeout=120s pods --all -n $NAMESPACE
echo "Setup completed"