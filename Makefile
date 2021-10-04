#!make


## install secret store
install-secrets-store:

## set up vault provider
setup-vault-provider:

## tests  service
test-service:    
	cd ./service/ && go test ../service/... && cd ..

## build  service
build-service: test-service
	cd ./service/ && CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o ./manifestservice ../service/cmd/main && cd ..

## run the service
run-service: build-service
	cd ./service/ && go run ./cmd/main/ && cd ..

## dockerize service
docker-service: build-service
	docker build -f ./service/Dockerfile -t $$API_BUILD_NAME:$$API_VERSION .	

#Deploy on k8s
kube-deploy: 
	



	

	