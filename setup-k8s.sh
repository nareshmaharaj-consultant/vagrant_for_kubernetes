cd ~
VER=1.27
PWD=`pwd`
IP=`hostname -i | awk '{print $2}'`
IP_MASTER=0.0.0.0
if [[ `hostname -s` = "master-node" ]]; then
        IP_MASTER=`hostname -i | awk '{print $2}'`
        echo $IP_MASTER
fi

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

sudo rm -f /etc/apt/sources.list.d/kubernetes.list
sudo apt-get clean

sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo sed -i 's/sandbox_image \= \"registry.k8s.io\/pause:3.6\"/sandbox_image \= \"registry.k8s.io\/pause:3.9\"/g' /etc/containerd/config.toml
sudo systemctl restart containerd
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
sudo apt-get install bash-completion -y
sudo apt-get install jq -y
kubectl completion bash >> ~/.bashrc

rm cni-plugins-linux-amd64*
rm containerd-*
rm runc.amd64*

# Set up accurate timeserver
sudo apt-get install -y ntpdate
sudo ntpdate -u pool.ntp.org
sudo systemctl restart systemd-timesyncd
sudo timedatectl set-ntp true

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
  sudo cp -f  /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo cp -f  /etc/kubernetes/admin.conf /shared/config
  echo -e sudo `kubeadm token create --print-join-command` > /shared/join_kubeadm_command.sh
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  echo "run the following command: [ watch kubectl get pods -n calico-system ]"
fi
