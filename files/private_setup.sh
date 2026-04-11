#!/bin/bash
set -e

# Configuración de instancia privada
# Este script instala y configura SSM agent, CloudWatch agent y otras herramientas

echo "=== Iniciando configuración de instancia privada ==="

# Actualizar paquetes del sistema
apt-get update
apt-get upgrade -y

# Instalar herramientas necesarias
apt-get install -y \
    curl \
    wget \
    git \
    net-tools \
    htop \
    vim \
    nano \
    awscli \
    jq

# SSM Agent (ya viene pre-instalado en Ubuntu 22.04 LTS, pero lo aseguramos)
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service

# CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Configurar CloudWatch Agent (logging básico)
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "syslog"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "${LOG_GROUP}",
            "log_stream_name": "auth"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": [
          {
            "name": "cpu_usage_idle",
            "rename": "CPU_USAGE_IDLE",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          {
            "name": "used_percent",
            "rename": "DISK_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          {
            "name": "mem_used_percent",
            "rename": "MEM_USED_PERCENT",
            "unit": "Percent"
          }
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Reemplazar variable LOG_GROUP en el archivo de configuración
sed -i "s|\${LOG_GROUP}|${LOG_GROUP}|g" /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Iniciar CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Crear un script de utilidad para verificar conectividad
cat > /usr/local/bin/check-nat-connectivity << 'EOF'
#!/bin/bash
echo "=== Verificando conectividad a NAT y Internet ==="
echo ""
echo "1. Verificando ruta por defecto (debe apuntar a NAT):"
ip route | grep default
echo ""
echo "2. Verificando conectividad HTTP:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://example.com
echo ""
echo "3. Verificando conectividad HTTPS:"
curl -s -o /dev/null -w "HTTPS Status: %{http_code}\n" https://example.com
echo ""
echo "4. Verificando DNS:"
nslookup example.com | grep "Address:"
EOF

chmod +x /usr/local/bin/check-nat-connectivity

# Crear script de auditoría
cat > /usr/local/bin/audit-instance << 'EOF'
#!/bin/bash
echo "=== Auditoría de instancia privada ==="
echo ""
echo "Información del sistema:"
hostnamectl status
echo ""
echo "Usuarios conectados:"
w
echo ""
echo "Sesiones SSM activas (visible en CloudTrail):"
aws ssm describe-sessions --filters "key=target,value=$(ec2-metadata --instance-id | cut -d' ' -f2)" --region $(ec2-metadata --availability-zone | sed 's/[a-z]$//')
echo ""
echo "Cambios recientes en archivos críticos:"
find /etc -type f -mtime -1 -ls 2>/dev/null | head -20
EOF

chmod +x /usr/local/bin/audit-instance

# Crear archivo de información del despliegue
cat > /etc/instance-info.txt << EOF
Instancia privada ${PROJECT_NAME}
Desplegada mediante Terraform
Fecha de despliegue: $(date)
CloudWatch Log Group: ${LOG_GROUP}
Acceso: SSM Session Manager (sin SSH)

Comandos útiles:
- check-nat-connectivity: Verificar conexión a Internet
- audit-instance: Auditar actividad de la instancia
EOF

# Limpiar logs temporales
apt-get clean
apt-get autoclean

# Crear un archivo de verificación de setup
echo "Setup completado exitosamente en $(date)" > /var/log/private-setup.log

echo "=== Configuración de instancia privada completada ==="
