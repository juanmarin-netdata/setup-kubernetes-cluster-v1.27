# Proyecto de Configuración de Clúster Kubernetes

Este proyecto contiene scripts para configurar un clúster de Kubernetes (v1.27) con un Plano de Control y Nodos de Trabajo, utilizando containerd como container runtime.

## Requisitos Previos

- **Ubuntu 20.04+**: Los scripts están diseñados para servidores Ubuntu.
- **Acceso a Internet**: Los scripts requieren acceso a internet para descargar e instalar paquetes.
- **Privilegios de Sudo**: El usuario que ejecute estos scripts debe tener privilegios de sudo.

## Scripts

### 1. `control_plane_setup.sh`

Este script configura el nodo de plano de control (master).

#### ¿Qué hace?
- Instala y configura `containerd`, `kubeadm`, `kubelet` y `kubectl`.
- Inicializa el plano de control de Kubernetes.
- Configura `kubectl` para acceso administrativo.
- Instala Calico como el complemento de red.
- Genera el comando de unión para los nodos de trabajo.

#### Uso:
```bash
sudo ./control_plane_setup.sh
```

### 2. `worker_node_setup.sh`

Este script configura los nodos de trabajo y los une al plano de control.

#### ¿Qué hace?
- Instala y configura `containerd`, `kubeadm` y `kubelet`.
- Ejecuta el join command por el plano de control para unir el nodo al clúster.

#### Uso:
- Transfiere el archivo `join_command.sh` generado por la configuración del plano de control a los nodos de trabajo.
- Luego ejecutar:
```bash
sudo ./worker_node_setup.sh
```

## Pasos para desplegar
- Ejecuta `control_plane_setup.sh` en el nodo de plano de control.
    - Este script inicializará el plano de control y generará un archivo `join_command.sh`.
- Transfiere `join_command.sh` a cada nodo de trabajo.
- Ejecuta `worker_node_setup.sh` en cada nodo de trabajo.
    - Este script unirá el nodo de trabajo al clúster.
- Verifica la configuración del clúster:
    - En el nodo de plano de control, ejecuta:
    ```bash
       kubectl get nodes
    ```
    - Todos los nodos deberían aparecer en estado `Ready`.

## Notas
- Los scripts incluyen mecanismos de reintento para manejar problemas transitorios de red.
- Asegúrate de revisar y comprender cada paso en los scripts antes de ejecutarlos.
