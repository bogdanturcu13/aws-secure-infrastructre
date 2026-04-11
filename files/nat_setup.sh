#!/bin/bash
set -e

# Configuración de NAT Instance
# Este script habilita el forwarding de paquetes IP y configura las reglas de firewall

echo "=== Iniciando configuración de NAT Instance ==="

# Actualizar paquetes del sistema
apt-get update
apt-get upgrade -y

# Instalar herramientas necesarias
apt-get install -y \
    curl \
    wget \
    net-tools \
    iptables-persistent \
    netfilter-persistent \
    awscli

# Habilitar forwarding de IP
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p > /dev/null

# Configurar iptables para NAT
# Habilitar masquerading para la subred privada hacia internet
iptables -t nat -A POSTROUTING -o eth0 -s ${PRIVATE_SUBNET_CIDR} -j MASQUERADE
iptables -A FORWARD -i eth0 -o eth0 -s ${PRIVATE_SUBNET_CIDR} -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# Guardar reglas de iptables (para persistencia después de reboot)
iptables-save > /etc/iptables/rules.v4

# Habilitar el servicio netfilter-persistent
systemctl enable netfilter-persistent
systemctl start netfilter-persistent

# Configurar CloudWatch Agent (opcional pero recomendado)
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb

# Deshabilitar source/destination check en la interfaz de red
# (Ya se hace en Terraform con source_dest_check = false, pero lo dejamos documentado)

# Crear un archivo de log para el setup
cat > /var/log/nat-setup.log << EOF
NAT Instance configurada exitosamente
Fecha: $(date)
IP Privada: $(hostname -I)
Subred privada permitida: ${PRIVATE_SUBNET_CIDR}
IP Forwarding: Habilitado
Masquerading: Configurado
EOF

echo "=== Configuración de NAT Instance completada ==="
