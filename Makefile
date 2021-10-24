#!/bin/bash

POC_NAMESPACE := "dev-csi-poc"


## install secret store
install-csi:
	chmod +x .deploy/secret_store/install_secret_store.sh
	.deploy/secret_store/install_secret_store.sh ${POC_NAMESPACE}

## set up vault provider
setup-vault-provider:
	chmod +x .deploy/vault_provider/setup_vault_provider.sh
	.deploy/vault_provider/setup_vault_provider.sh ${POC_NAMESPACE}

## build service
build-service: 
	cd ./service/ && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ./goservice ../service/cmd/main && cd ..

## dockerize service
docker-service: build-service
	docker build -f ./service/Dockerfile -t goservice-csi:0.0.1 .	

kube-deploy: docker-service
	kubectl apply -f .deploy/go_service/deployment.yaml -n ${POC_NAMESPACE}

kube-redeploy:
	kubectl delete -f .deploy/go_service/deployment.yaml -n ${POC_NAMESPACE}
	kubectl apply -f .deploy/go_service/deployment.yaml -n ${POC_NAMESPACE}

#destroy namespace
destroy:
	kubectl delete ns ${POC_NAMESPACE}