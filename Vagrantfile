NUM_WORKER_NODES=3
IP_NW="10.0.0."
IP_START=10
IP_NW_PUBLIC="192.168.0."
IP_START_PUBLIC=200

Vagrant.configure("2") do |config|
  config.vm.provision "shell", env: {"IP_NW" => IP_NW, "IP_START" => IP_START}, inline: <<-SHELL
      apt-get update -y
      echo "$IP_NW$((IP_START)) master-node" >> /etc/hosts
  SHELL
 
  (1..NUM_WORKER_NODES).each do |i|
    INTERNAL_IP = IP_NW + "#{IP_START + i}"
    config.vm.provision "shell", env: {"IP_NW" => IP_NW, "IP_START" => IP_START}, inline: <<-SHELL
      echo #{INTERNAL_IP} worker-node0#{i} >> /etc/hosts
    SHELL
  end

  config.vm.synced_folder "shared/", "/shared", create: true
  config.vm.synced_folder "data/", "/data", create: true
  config.vm.provision "shell", path: "swap.off.sh"
  config.vm.provision "shell", path: "add-fw-rules.sh"
  config.vm.box = "bento/ubuntu-22.04"
  config.vm.box_check_update = true
  config.vm.boot_timeout = 600
  config.vm.provision "file", source: "setup-k8s.sh", destination: "setup-k8s.sh"
  config.vm.provision "shell", inline: <<-SHELL
    chmod +x /home/vagrant/setup-k8s.sh
    sudo apt install dos2unix
    dos2unix setup-k8s.sh
  SHELL
  config.vm.network "public_network", bridge: "en0: Wi-Fi"

  config.vm.define "master" do |master|
    master.vm.hostname = "master-node"
    master.vm.network "private_network", ip: IP_NW + "#{IP_START}"
    master.vm.network "public_network", ip: IP_NW_PUBLIC + "#{IP_START_PUBLIC}", bridge: "en0: Wi-Fi"
    master.vm.provider "virtualbox" do |vb|
        vb.memory = 4048
        vb.cpus = 2
    end
  end

  (1..NUM_WORKER_NODES).each do |i|

  config.vm.define "node0#{i}" do |node|
    node.vm.hostname = "worker-node0#{i}"
    node.vm.network "private_network", ip: IP_NW + "#{IP_START + i}"
    node.vm.network "public_network", ip: IP_NW_PUBLIC + "#{IP_START_PUBLIC + i}", bridge: "en0: Wi-Fi"
    node.vm.provider "virtualbox" do |vb|
        vb.memory = 7168
        vb.cpus = 2
    end
  end

  end
end 
