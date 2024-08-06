# vagrant-for-kubeadm

- Will create an Ubuntu Kubernets cluster.
- Disable swap
- add firewall rules
- Enable required ports for inter vm connectivity
- creates a setup script to be run on all hosts to CRI, CNI, kubeadm kubectl, ..

 > If you are using a Mac you may wish to update the allowed address range by adding the following to /etc/vbox/networks.conf
<BR>10.0.0.0/8 192.168.0.0/16
<BR>2001::/64

 > run
 > _start.sh
 > After the cluster has been formed then run the following on each node. After completion then use the kubeadm join commmands on thr worker nodes.
   > <BR>./setup-k8s.sh
   > <BR>source ~/.bashrc
 > 
