# Kubernetes Secrets Store CSI Driver POC


[Container Storage Interface]() is a standard for exposing arbitaryy block and
file storage systems to containerized workloads in Kubernetes. There various third-party uses
of the Container Storage Interface. 

The [Secrets Store CSI driver]() is just one of the many drivers that takes advantage of the Container Storage Interface.
It uses a list of compartible providers to make secrets managed _outside_ Kubernetes available _in_ Kubernetes via Container Storage Interface.

There are a couple of providers supported which can work with Secrets Store CSI driver.

1. [AWS Provider]() : For Ayure Key Vault 
2. [Azure Provider]() : For AWS Secrets Manager
3. [GCP Provider]() : For Google Secret Manager
4. [Vault Provider]() : For Hashicorp Vault.

This article and POC will focus much more on the Vault Provider.
That is the goal of this article is so way to use and manage 
externalized secrets stored on vault in hte Kubernetes cluster via the Kubernetes-native API.  

What are some advantages of doing this: 

1. No need to manage clients for where secrets are stored.
2. Secrets Store CSI driver using the native Kubernetes-API means there'll a more organized way of upgrading during cluster upgrades compared to multiple clients.
3. The abstraction provided by Secrets Store CSI driver makes it easier to build a much more cloud agnostic infrastructure not tied to one Secret manager.  
4. [The Twelve Factor App]() guideline for storing secrets as environment variables can be achieved with this.


### 1. Architecture





We have a simple Go application, that will access secrets stored on vault provisioned by the Secrets Store CSI driver.
### 2. Set up

#### 1. Configure Secrets Store CSI driver and Vault Provider

1. To set up the POC clone the [repository]().
2. cd into the directory. 
3. Make sure you're connected to the right cluster.
4. Install Secrets Store CSI driver into our cluster by running `make install-csi`.  This should install the Secrets Store CSI driver into the cluster and also create the namespace `dev-csi-poc`.
5. Install the [Vault Provider]() using `make setup-vault-provider`.
The deployment manifest for the Vault Provider looks like this.
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-csi-provider
  namespace: dev-csi-poc
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: vault-csi-provider-clusterrole
rules:
- apiGroups:
  - ""
  resources:
  - serviceaccounts/token
  verbs:
  - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-csi-provider-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: vault-csi-provider-clusterrole
subjects:
- kind: ServiceAccount
  name: vault-csi-provider
  namespace: dev-csi-poc
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: vault-csi-provider
  name: vault-csi-provider
  namespace: dev-csi-poc
spec:
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: vault-csi-provider
  template:
    metadata:
      labels:
        app: vault-csi-provider
    spec:
      serviceAccountName: vault-csi-provider
      tolerations:
      containers:
        - name: provider-vault-installer
          image: hashicorp/vault-csi-provider:0.3.0
          imagePullPolicy: Always
          args:
            - --endpoint=/provider/vault.sock
            - --debug=false
          resources:
            requests:
              cpu: 50m
              memory: 100Mi
            limits:
              cpu: 50m
              memory: 100Mi
          volumeMounts:
            - name: providervol
              mountPath: "/provider"
            - name: mountpoint-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: HostToContainer
          livenessProbe:
            httpGet:
              path: "/health/ready"
              port: 8080
              scheme: "HTTP"
            failureThreshold: 2
            initialDelaySeconds: 5
            periodSeconds: 5
            successThreshold: 1
            timeoutSeconds: 3
          readinessProbe:
            httpGet:
              path: "/health/ready"
              port: 8080
              scheme: "HTTP"
            failureThreshold: 2
            initialDelaySeconds: 5
            periodSeconds: 5
            successThreshold: 1
            timeoutSeconds: 3
      volumes:
        - name: providervol
          hostPath:
            path: "/etc/kubernetes/secrets-store-csi-providers"
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
      nodeSelector:
        beta.kubernetes.io/os: linux
```
6. Ensure our Vault installation has Kubernetes [auth enabled](https://www.vaultproject.io/docs/auth/kubernetes). 
7. Create a path for our secret, `vault secrets enable -path=service-a kv-v2`
8. Put in a sample password `vault kv put service-a/database password=secret1234` for our made up service.
9. Create a vault policy to enable us read the secrets for our made up service.
```commandline
vault policy write service-a-policy -<<EOF
   path "service-a/data/database" {
   capabilities = ["read"]
   }
   EOF
```
10. Create a Kubernetes Auth role that grants that allows for the reading of secrets to the service account in a specific namespace.
```commandline
vault write auth/kubernetes/role/csi \
    bound_service_account_names=secrets-store-csi-driver,goservice-csi-serviceaccount,vault-csi-provider \
    bound_service_account_namespaces=dev-csi-poc \
    policies=service-a-policy ttl=720m
```

Now we've set completed the setup Secrets Store CSI driver, Vault Provider and enabled
kubernetes auth role to the ServiceAccount in the namesapce `ev-csi-poc`


#### 2. Deploy Service

The setup is ready for the deployment of the service.
The deployment manifest for our simple Go service has a custom resource
called **SecretProviderClass**, which was installed when we deployed Secrets Store CSI driver.

It looks something like this. 

```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1alpha1
kind: SecretProviderClass
metadata:
  name: goservice-vault-provider
spec:
  provider: vault
  parameters:
    roleName: "csi"
    vaultAddress: "http://vault.vault:8200"
    vaultSkipTLSVerify: "true"
    objects:  |
      - secretPath: "service-a/data/database"
        objectName: "password"
        secretKey: "password"

```

Few things to note are:

1. **vaultAddress** : The URL to our vault.
2. **roleName** : The kubernetes role created in vault to access the secrets.
3. **objects**: Details of the secrets we want to mount. 

We can also mount multiple secrets, certs in the same cluster.

Now to use it as environment variables, we mount **SecretProviderClass** as a volume. 
```yaml
       env:            
          volumeMounts:
            - name: goservice-store-inline
              mountPath: "/mnt/secrets-store"
              readOnly: true
        volumes:
          - name: goservice-store-inline
            csi:
              driver: secrets-store.csi.k8s.io
              readOnly: true
              volumeAttributes:
                secretProviderClass: goservice-vault-provider
```

To deploy this, let's run `make kube-deploy` to install the service into the cluster.

#### 3. Test Setup 

To test we need to confirm if the secret path configured in vault is accessible in the pod.

1. Run `kubectl get po -n dev-csi-poc` to get pods in the namespace. You should have something like this: 

```commandline
NAME                                               READY   STATUS    RESTARTS   AGE
csi-secrets-store-secrets-store-csi-driver-6zkk7   3/3     Running   0          2m49s
goservice-csi-c8b66664d-kdgjk                      1/1     Running   0          88s
vault-csi-provider-hww87                           1/1     Running   0          2m1s
```

2. Connect to the pod, with `kubectl exec goservice-csi-c8b66664d-kdgjk -n dev-csi-poc --  ls /mnt/secrets-store`. Since we've mounted our vault secrets to this path _/mnt/secrets-store_
3. You can proceed and `cat` the password to confirm if the secret stored in vault will be accessible. 
`kubectl exec goservice-csi-c8b66664d-kdgjk -n dev-csi-poc -- cat /mnt/secrets-store/password`
4. The Go service also provides an httpendpoint to read contents of the file _/mnt/secrets-store/password_. This can be accessed by getting the NodePort and then accessing the path `/vault`. You should see the contents of password file displayed.

`kubectl get svc -n dev-csi-poc` with the output :
```commandline
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
goservice-csi   NodePort   10.104.91.25   <none>        8080:31510/TCP   12m
```
`curl http://localhost:31510/vault` as an alternative checkpoint.

Few things to note, the CSI driver is invoked by kubelet only during the pod volume mount. 
So subsequent changes in the SecretProviderClass after the pod has started doesn’t trigger an update to the content in volume mount or Kubernetes secret. There's also a way to enable autorotation of secrets
without having to restart the pod. However, this is still in [alpha](https://github.com/kubernetes-sigs/secrets-store-csi-driver/blob/55efc2dd1a8b64d7f7961d769c79c8100398a555/docs/book/src/topics/secret-auto-rotation.md).



 
 


