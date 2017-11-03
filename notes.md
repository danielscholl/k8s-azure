# Helpful Kubernetes Commands

## Cluster Management

```bash
# Create a Cluster
kubeadmin init

To start using your cluster, you need to run (as a regular user):

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/admin.conf

# List all nodes
kubectl get nodes

# List all pods
kubectl get pods --all-namespaces

# Create a pod network (multi host overlay from weaveworks)
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"


# Add a node to the cluster
sudo kubeadm join --toekn {TOKEN} {IP_ADDRESS}

sudo kubeadm join --token 6dc3c8.096a135034f6fb5f 10.1.0.5:6443 --discovery-token-ca-cert-hash sha256:23d8917e19fd246f27b0794b10248fc5f0c12f52ad5115312c53fa180c4bed48

# Add a worker
docker swarm join-token worker
docker swarm join --token {TOKEN} node1:2377
docker info |grep ^Swarm

# Managing nodes
docker node ls
docker node promote <node_name_or_id>

```
