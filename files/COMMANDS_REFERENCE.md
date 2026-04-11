# 📖 Referencia de Comandos y Troubleshooting

## 🎯 Comandos Básicos de Terraform

### Inicialización y Validación

```bash
# Inicializar proyecto Terraform
terraform init

# Validar sintaxis
terraform validate

# Formatear código (best practice)
terraform fmt -recursive

# Ver estado actual
terraform show

# Mostrar recursos específicos
terraform state list
terraform state show aws_instance.private_server
```

### Planificación y Despliegue

```bash
# Ver qué cambios hará
terraform plan

# Guardar plan para aplicar luego
terraform plan -out=tfplan

# Aplicar cambios
terraform apply
terraform apply tfplan

# Destruir recursos
terraform destroy
terraform destroy -target=aws_instance.nat  # Recurso específico

# Actualizar estado
terraform refresh
```

### Outputs

```bash
# Ver todos los outputs
terraform output

# Valor específico
terraform output nat_instance_public_ip

# Formato JSON
terraform output -json

# Valor específico en JSON
terraform output -json private_server_details | jq '.instance_id'
```

---

## 🔧 Comandos AWS CLI - Instancias

### Ver Instancias

```bash
# Listar todas las instancias del proyecto
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=secure-cloud-arch" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]' \
  --output table

# Ver detalles específicos de instancia
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxx \
  --query 'Reservations[0].Instances[0]'

# Ver información de red
aws ec2 describe-network-interfaces \
  --filters "Name=tag:Name,Values=secure-cloud-arch*"
```

### Gestión de Instancias

```bash
# Iniciar instancia
aws ec2 start-instances --instance-ids i-xxxxxxxx --region eu-west-1

# Parar instancia (no terminar)
aws ec2 stop-instances --instance-ids i-xxxxxxxx --region eu-west-1

# Terminar instancia (CUIDADO: irreversible)
aws ec2 terminate-instances --instance-ids i-xxxxxxxx --region eu-west-1

# Ver logs de consola
aws ec2 get-console-output --instance-id i-xxxxxxxx

# Obtener datos de instancia
aws ec2-instance-connect send-ssh-public-key ...
```

### Monitores y Métricas

```bash
# Ver estado y cambios recientes
aws ec2 describe-instance-status \
  --instance-ids i-xxxxxxxx \
  --query 'InstanceStatuses[*].[InstanceId,InstanceStatus.Status,SystemStatus.Status]'

# Ver eventos de instancia
aws ec2 describe-instance-status \
  --instance-ids i-xxxxxxxx \
  --query 'InstanceStatuses[0].Events'
```

---

## 🔐 Comandos AWS CLI - Seguridad

### Security Groups

```bash
# Listar SGs del proyecto
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=secure-cloud-arch*" \
  --query 'SecurityGroups[*].[GroupId,GroupName]' \
  --output table

# Ver reglas de entrada
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxx \
  --query 'SecurityGroups[0].IpPermissions' \
  --output table

# Ver reglas de salida
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxx \
  --query 'SecurityGroups[0].IpPermissionsEgress' \
  --output table

# Agregar regla entrante
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.2.0/24

# Remover regla
aws ec2 revoke-security-group-ingress \
  --group-id sg-xxxxxxxx \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.2.0/24
```

### KMS

```bash
# Listar claves KMS
aws kms list-keys

# Ver detalles de clave
aws kms describe-key --key-id alias/secure-cloud-arch-ebs

# Ver políticas de clave
aws kms get-key-policy \
  --key-id alias/secure-cloud-arch-ebs \
  --policy-name default

# Listar grants (delegaciones) de clave
aws kms list-grants --key-id alias/secure-cloud-arch-ebs

# Ver estado de rotación
aws kms get-key-rotation-status \
  --key-id alias/secure-cloud-arch-ebs
```

### IAM

```bash
# Listar roles del proyecto
aws iam list-roles \
  --query "Roles[?contains(RoleName, 'secure-cloud-arch')]"

# Ver políticas adjuntas a rol
aws iam list-attached-role-policies \
  --role-name secure-cloud-arch-private-server-role

# Ver política específica
aws iam get-role-policy \
  --role-name secure-cloud-arch-private-server-role \
  --policy-name secure-cloud-arch-private-server-kms-policy

# Ver Instance Profile
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

---

## 📊 Comandos AWS CLI - Auditoría y Logging

### CloudTrail

```bash
# Ver estado de CloudTrail
aws cloudtrail describe-trails \
  --trail-name-list secure-cloud-arch-trail

# Buscar eventos específicos
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=AuthorizeSecurityGroupIngress \
  --max-results 10

# Buscar por usuario
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=tu-usuario \
  --max-results 10

# Ver cambios en SG
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=secure-cloud-arch-nat-sg \
  --max-results 20

# Buscar eventos por rango de tiempo
aws cloudtrail lookup-events \
  --start-time 2025-02-01T00:00:00Z \
  --end-time 2025-02-06T23:59:59Z \
  --max-results 50

# Exportar a JSON
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartSession \
  --max-results 100 > cloudtrail-events.json
```

### CloudWatch Logs

```bash
# Listar log groups
aws logs describe-log-groups \
  --query "logGroups[?contains(logGroupName, 'secure-cloud-arch')]"

# Ver streams en log group
aws logs describe-log-streams \
  --log-group-name /aws/ssm/secure-cloud-arch

# Ver últimos logs
aws logs tail /aws/ssm/secure-cloud-arch --follow

# Ver logs específicos
aws logs get-log-events \
  --log-group-name /aws/ssm/secure-cloud-arch \
  --log-stream-name 'i-xxxxxxxx'

# Filtrar eventos
aws logs filter-log-events \
  --log-group-name /aws/cloudtrail/secure-cloud-arch \
  --filter-pattern "AuthorizeSecurityGroupIngress"

# Ver logs CloudTrail
aws logs tail /aws/cloudtrail/secure-cloud-arch

# Ver logs de VPC Flow
aws logs tail /aws/vpc/flow-logs/secure-cloud-arch
```

### S3 (CloudTrail Logs)

```bash
# Listar buckets del proyecto
aws s3 ls | grep cloudtrail

# Ver contenido del bucket CloudTrail
aws s3 ls s3://secure-cloud-arch-cloudtrail-logs-ACCOUNT-ID/

# Descargar logs específicos
aws s3 cp s3://secure-cloud-arch-cloudtrail-logs-ACCOUNT-ID/AWSLogs/ACCOUNT-ID/CloudTrail/ . --recursive

# Ver tamaño del bucket
aws s3api list-objects-v2 \
  --bucket secure-cloud-arch-cloudtrail-logs-ACCOUNT-ID \
  --query 'Contents[].[Key,Size]' \
  | awk '{sum+=$2} END {print "Total bytes: " sum " (" sum/1024/1024 " MB)"}'
```

---

## 🔗 Comandos AWS CLI - Networking

### VPC y Subredes

```bash
# Ver VPC del proyecto
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=secure-cloud-arch-vpc"

# Ver subredes
aws ec2 describe-subnets \
  --filters "Name=tag:Tier,Values=Public" \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' \
  --output table

# Ver tablas de rutas
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=secure-cloud-arch*" \
  --query 'RouteTables[*].[RouteTableId,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Ver rutas específicas
aws ec2 describe-route-tables \
  --route-table-ids rtb-xxxxxxxx \
  --query 'RouteTables[0].Routes'
```

### Internet Gateway

```bash
# Ver IGW
aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=secure-cloud-arch-igw"

# Ver asociaciones IGW-VPC
aws ec2 describe-internet-gateways \
  --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId]'
```

### VPC Flow Logs

```bash
# Ver Flow Logs configurados
aws ec2 describe-flow-logs \
  --filter "Name=resource-id,Values=vpc-xxxxxxxx"

# Ver logs en CloudWatch
aws logs tail /aws/vpc/flow-logs/secure-cloud-arch --follow

# Analizar tráfico rechazado
aws logs filter-log-events \
  --log-group-name /aws/vpc/flow-logs/secure-cloud-arch \
  --filter-pattern "[version, account, eni, source, destination, srcport, destport="22", protocol, packets, bytes, windowstart, windowend, action="REJECT", flowlogstatus]" \
  --max-items 50
```

---

## 🖥️ Comandos para Acceder a Instancias

### SSM Session Manager

```bash
# Conectar a instancia privada
aws ssm start-session --target i-xxxxxxxx --region eu-west-1

# Ver sesiones activas
aws ssm describe-sessions \
  --filters "key=target,value=i-xxxxxxxx"

# Terminar sesión
aws ssm terminate-session --session-id xxxxx

# Port Forwarding (si fuera necesario)
aws ssm start-session \
  --target i-xxxxxxxx \
  --document-name AWS-StartPortForwardingSession \
  --parameters 'localPortNumber=3306,portNumber=3306'
```

### Dentro de la Instancia Privada

```bash
# Una vez conectado via SSM, verificar conectividad
ip route                           # Ver ruta por defecto (NAT)
curl http://example.com           # Probar HTTP
curl https://example.com          # Probar HTTPS
nslookup example.com              # Probar DNS
dig example.com +short            # Alternativa DNS

# Ver configuración de red
ifconfig                          # Dirección IP (10.0.2.x)
netstat -rn                       # Tabla de rutas
ss -tlnp                          # Puertos escuchando

# Ver logs locales
tail -f /var/log/syslog
tail -f /var/log/auth.log         # Intentos de acceso

# Ver estado de CloudWatch Agent
systemctl status amazon-cloudwatch-agent

# Ver disponibilidad de utilidades instaladas
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
```

---

## 🐛 Troubleshooting

### Problema: Instancia privada no puede acceder a Internet

```bash
# 1. Verificar ruta por defecto (dentro de instancia)
ip route                 # Debe mostrar: default via 10.0.1.x dev eth0

# 2. Probar conectividad a NAT
ping 10.0.1.x            # IP privada de NAT

# 3. Verificar Security Group (desde local)
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx (NAT)
# Debe permitir entrada 80 y 443 desde 10.0.2.0/24

# 4. Verificar que NAT tiene IP pública
aws ec2 describe-instances \
  --instance-ids i-xxxxxxxx-nat \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# 5. Verificar source_dest_check en NAT
aws ec2 describe-network-interfaces \
  --network-interface-ids eni-xxxxxxxx \
  --query 'NetworkInterfaces[0].SourceDestCheck'
# Debe ser: false

# 6. Verificar IP Forwarding en NAT
# Conectar a NAT via SSM y ejecutar:
cat /proc/sys/net/ipv4/ip_forward    # Debe ser 1

# 7. Verificar iptables en NAT
iptables -t nat -L                   # Ver reglas masquerading
iptables -t nat -L -n                # Sin resolver nombres
```

### Problema: No puedo acceder vía SSM

```bash
# 1. Verificar que Instance Profile está asignado
aws ec2 describe-instances --instance-ids i-xxxxxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'

# 2. Verificar que IAM role tiene permisos SSM
aws iam list-attached-role-policies \
  --role-name secure-cloud-arch-private-server-role

# 3. Verificar que SSM agent está corriendo (SSM a instancia)
aws ssm start-session --target i-xxxxxxxx
# Dentro: systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service

# 4. Verificar que Security Group NO tiene inbound rules
aws ec2 describe-security-groups --group-ids sg-private-server \
  --query 'SecurityGroups[0].IpPermissions'
# Debe estar vacío

# 5. Ver logs de CloudTrail para errores
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartSession \
  --max-results 10

# 6. Si SSM es nuevo, instancia puede tardar 5-10 minutos en registrarse
sleep 300  # Esperar 5 minutos y reintentar
```

### Problema: Terraform se queja de estado

```bash
# 1. Refrescar estado
terraform refresh

# 2. Validar estado
terraform validate

# 3. Ver state inconsistencias
terraform plan -detailed-exitcode

# 4. Si necesitas resetear estado (CUIDADO)
terraform state pull > backup.json
terraform state rm aws_instance.nat  # Remover recurso

# 5. Re-importar si es necesario
terraform import aws_instance.nat i-xxxxxxxx

# 6. Si todo falla, destruir y redeploy
terraform destroy
rm -rf .terraform terraform.tfstate*
terraform init
terraform apply
```

### Problema: Costos inesperados

```bash
# 1. Ver configuración actual
terraform show | grep instance_type

# 2. Verificar todos los recursos creados
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=secure-cloud-arch" \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]'

# 3. Ver volúmenes EBS
aws ec2 describe-volumes \
  --filters "Name=tag:Name,Values=*secure-cloud-arch*" \
  --query 'Volumes[*].[VolumeId,Size,State]'

# 4. Ver buckets S3
aws s3 ls | grep cloudtrail

# 5. Cambiar instance type a más pequeño
# Editar variables.tf:
# nat_instance_type = "t3.nano"
# private_instance_type = "t3.nano"
terraform apply

# 6. Reducir tamaño de volúmenes
# Editar instances.tf, cambiar volume_size
# Nota: Algunos cambios requieren destroyrecreate
```

### Problema: CloudTrail no graba eventos

```bash
# 1. Verificar que CloudTrail está habilitado
aws cloudtrail describe-trails --trail-name-list secure-cloud-arch-trail

# 2. Verificar que CloudTrail está logging
aws cloudtrail get-trail-status \
  --name arn:aws:cloudtrail:eu-west-1:ACCOUNT-ID:trail/secure-cloud-arch-trail

# 3. Verificar que bucket S3 tiene permisos
aws s3api get-bucket-policy \
  --bucket secure-cloud-arch-cloudtrail-logs-ACCOUNT-ID

# 4. Si logs están en S3, verificar que CloudWatch también recibe
aws logs describe-log-streams \
  --log-group-name /aws/cloudtrail/secure-cloud-arch

# 5. Esperar 5 minutos - CloudTrail tiene latencia
sleep 300

# 6. Buscar eventos nuevos
aws cloudtrail lookup-events --max-results 10
```

### Problema: KMS - Acceso denegado

```bash
# 1. Verificar que la clave existe
aws kms describe-key --key-id alias/secure-cloud-arch-ebs

# 2. Verificar permisos de IAM role
aws iam get-role-policy \
  --role-name secure-cloud-arch-private-server-role \
  --policy-name secure-cloud-arch-private-server-kms-policy

# 3. Verificar política de clave KMS
aws kms get-key-policy \
  --key-id alias/secure-cloud-arch-ebs \
  --policy-name default | jq '.'

# 4. Verificar que EC2 tiene acceso
# Debería tener statement para "ec2.amazonaws.com"

# 5. Si recreas la clave, actualizar políticas
# Editar kms.tf y terraform apply
```

---

## 📝 Logs Útiles para Revisar Regularmente

```bash
# Auditoría semanal
aws logs tail /aws/cloudtrail/secure-cloud-arch --since 7d

# Ver cambios en infraestructura
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventSource,AttributeValue=ec2.amazonaws.com \
  --since 7d --max-results 100

# Sesiones SSM
aws logs tail /aws/ssm/secure-cloud-arch --since 1d

# Errores de auth
aws logs filter-log-events \
  --log-group-name /aws/ssm/secure-cloud-arch \
  --filter-pattern "ERROR" --since 1d

# VPC rechazos
aws logs tail /aws/vpc/flow-logs/secure-cloud-arch \
  --filter-pattern "REJECT"
```

---

## ⚡ Alias Útiles (añadir a .bashrc)

```bash
# Alias para comandos frecuentes
alias tf='terraform'
alias tfi='terraform init'
alias tfv='terraform validate'
alias tfp='terraform plan'
alias tfa='terraform apply'
alias tfd='terraform destroy'
alias tfo='terraform output'

# AWS CLI aliases
alias awslogs='aws logs tail --follow'
alias awsinstances='aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress,PublicIpAddress]" --output table'
alias awssgs='aws ec2 describe-security-groups --query "SecurityGroups[*].[GroupId,GroupName]" --output table'

# Función para conectar rápido a instancia
ssm-connect() {
  aws ssm start-session --target "$1" --region eu-west-1
}
```

---

**Última actualización**: 2025-02-06
**Versión**: 1.0
