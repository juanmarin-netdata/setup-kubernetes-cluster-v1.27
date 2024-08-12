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

# Instalar kubelet y kubeadm (sin kubectl)
echo "Instalando kubelet y kubeadm..."
retry_command sudo apt-get install -y kubelet kubeadm

# Marcar kubelet y kubeadm para que no se actualicen automáticamente
echo "Deshabilitando actualizaciones automáticas de kubelet y kubeadm..."
retry_command sudo apt-mark hold kubelet kubeadm

echo "¡Configuración completa!"

# Usar el comando de unión generado en el nodo de control
echo "Uniendo el nodo de trabajo al clúster..."
sudo ./join_command.sh

echo "¡El nodo de trabajo se ha unido al clúster con éxito!"
