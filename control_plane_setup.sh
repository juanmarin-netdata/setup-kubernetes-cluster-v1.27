#!/bin/bash

# Función para reintentar comandos
retry_command() {
    local retries=5
    local wait_time=150
    local count=0

    until "$@"; do
        exit_code=$?
        count=$((count + 1))
        if [ $count -lt $retries ]; then
            echo "Intento $count/$retries fallido. Reintentando en $wait_time segundos..."
            sleep $wait_time
        else
            echo "El comando ha fallado después de $count intentos."
            return $exit_code
        fi
    done

    return 0
}

# Cargar módulos necesarios
echo "Cargando módulos necesarios..."
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

retry_command sudo modprobe overlay
retry_command sudo modprobe br_netfilter

# Configurar parámetros del sistema para Kubernetes
echo "Configurando parámetros del sistema para Kubernetes..."
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

retry_command sudo sysctl --system

# Instalar containerd
echo "Instalando containerd..."
retry_command sudo apt-get update
retry_command sudo apt-get install -y containerd

# Crear y configurar el archivo de configuración de containerd
echo "Configurando containerd..."
sudo mkdir -p /etc/containerd
retry_command sudo containerd config default | sudo tee /etc/containerd/config.toml

# Reiniciar containerd para aplicar la nueva configuración
echo "Reiniciando containerd..."
retry_command sudo systemctl restart containerd

# Verificar que containerd está corriendo
echo "Verificando que containerd está corriendo..."
retry_command sudo systemctl status containerd

# Deshabilitar el uso de swap
echo "Deshabilitando swap..."
retry_command sudo swapoff -a

# Instalar dependencias
echo "Instalando dependencias..."
retry_command sudo apt-get update
retry_command sudo apt-get install -y apt-transport-https curl

# Descargar y añadir la clave GPG del repositorio de Kubernetes
echo "Añadiendo la clave GPG del repositorio de Kubernetes..."
sudo mkdir -p /etc/apt/keyrings
retry_command curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.27/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Añadir el repositorio de Kubernetes a la lista de repositorios
echo "Añadiendo el repositorio de Kubernetes..."
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.27/deb/ /
EOF

# Actualizar los listados de paquetes
echo "Actualizando los listados de paquetes..."
retry_command sudo apt-get update

# Instalar kubelet, kubeadm y kubectl
echo "Instalando kubelet, kubeadm y kubectl..."
retry_command sudo apt-get install -y kubelet kubeadm kubectl

# Marcar kubelet, kubeadm y kubectl para que no se actualicen automáticamente
echo "Deshabilitando actualizaciones automáticas de kubelet, kubeadm y kubectl..."
retry_command sudo apt-mark hold kubelet kubeadm kubectl

echo "¡Configuración completa!"

# Inicializar el clúster de Kubernetes en el nodo de control
echo "Inicializando el clúster de Kubernetes..."
retry_command sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --kubernetes-version 1.27.11

# Configurar acceso a kubectl inmediatamente después de la inicialización
echo "Configurando acceso a kubectl..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "¡Configuración de kubectl completada!"

# Probar acceso al clúster
echo "Esperando a que el clúster esté disponible..."
sleep 30  # Espera para permitir que el clúster esté completamente disponible

retry_command kubectl get nodes

# Instalar Calico para la red del clúster
echo "Instalando Calico Networking..."
retry_command kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml

# Comprobar el estado del nodo de control
echo "Comprobando el estado del nodo de control..."
retry_command kubectl get nodes

# Crear el comando de unión para los nodos de trabajo
echo "Generando comando de unión para los nodos de trabajo..."
retry_command kubeadm token create --print-join-command > join_command.sh
echo "El comando de unión se ha guardado en join_command.sh. Ejecútalo en los nodos de trabajo para unirlos al clúster."

echo "¡Proceso completado!"
