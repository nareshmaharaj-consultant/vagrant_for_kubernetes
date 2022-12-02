cd ~
VER=1.19.12
PWD=`pwd`
IP_MASTER="10.0.0.10"
IP=`hostname -i | awk '{print $2}'`

sudo modprobe br_netfilter

echo "START Forwarding IPv4 and letting iptables see bridged traffic"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
echo "COMPLETED Forwarding IPv4 and letting iptables see bridged traffic"

wget https://github.com/containerd/containerd/releases/download/v1.6.9/containerd-1.6.9-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local ${PWD}/containerd-1.6.9-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
sudo mv ${PWD}/containerd.service /lib/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now containerd
wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64
sudo install -m 755 ${PWD}/runc.amd64 /usr/local/sbin/runc
wget https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin ${PWD}/cni-plugins-linux-amd64-v1.1.1.tgz

sudo mkdir -p /etc/containerd/
containerd config default | sudo tee -a /etc/containerd/config.toml
sudo systemctl restart containerd
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
#sudo apt-get install -y kubelet=1.25.1-00 kubeadm=1.25.1-00 kubectl=1.25.1-00
sudo apt-get install -y kubelet=${VER}-00 kubeadm=${VER}-00 kubectl=${VER}-00
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
sudo apt-get install bash-completion
sudo apt-get install jq
kubectl completion bash >> ~/.bashrc

rm cni-plugins-linux-amd64*
rm containerd-*
rm runc.amd64*

# kubeadm on master only
if [ $IP = $IP_MASTER ]
then
  sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --apiserver-advertise-address=$IP
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.2/manifests/tigera-operator.yaml
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.2/manifests/custom-resources.yaml
  kubectl taint nodes --all node-role.kubernetes.io/control-plane-
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  echo "run the following command: [ watch kubectl get pods -n calico-system ]"
fi

# Lua
curl -R -O http://www.lua.org/ftp/lua-5.4.4.tar.gz
tar zxf lua-5.4.4.tar.gz
cd lua-5.4.4
make all test
sudo make install
