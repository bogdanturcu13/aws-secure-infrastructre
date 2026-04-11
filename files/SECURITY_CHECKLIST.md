# 🔐 Guía de Buenas Prácticas y Checklist de Seguridad

## ✅ Pre-Despliegue

### Seguridad AWS
- [ ] Verificar que tienes MFA habilitado en tu cuenta AWS
- [ ] Usar credenciales de IAM (no root) para Terraform
- [ ] Verificar que tienes permisos suficientes para crear recursos
- [ ] Habilitar CloudTrail en la cuenta (si no está habilitado globalmente)

### Configuración Local
- [ ] Instalar Terraform v1.0 o superior: `terraform version`
- [ ] Instalar AWS CLI v2: `aws --version`
- [ ] Verificar credenciales AWS: `aws sts get-caller-identity`
- [ ] Crear archivo `.gitignore` para no commitear estado de Terraform

### Variables
- [ ] Revisar `terraform.tfvars` con valores apropiados
- [ ] Cambiar `project_name` a algo único en tu organización
- [ ] Verificar CIDR blocks que no conflictúen con VPCs existentes
- [ ] Seleccionar región apropiada (eu-west-1 por defecto)

---

## 🚀 Durante el Despliegue

### Validación Previa
```bash
# Validar sintaxis
terraform validate

# Revisar plan completo ANTES de aplicar
terraform plan -out=tfplan

# Revisar cambios específicos
terraform show tfplan
```

### Despliegue
- [ ] Ejecutar `terraform plan` y revisar cuidadosamente
- [ ] Confirmar la creación de cada recurso
- [ ] Guardar los outputs de Terraform
- [ ] Esperar a que todas las instancias estén en "running"

---

## ✔️ Post-Despliegue Inmediato

### Verificaciones Técnicas
```bash
# 1. Obtener outputs
terraform output

# 2. Verificar instancias
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=secure-cloud-arch" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'

# 3. Verificar Security Groups
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*secure-cloud-arch*"

# 4. Verificar IAM Roles
aws iam list-roles --query 'Roles[?contains(RoleName, `secure-cloud-arch`)].{Name:RoleName,Arn:Arn}'
```

### Acceso y Conectividad
- [ ] Intentar conectar a la instancia privada mediante SSM
- [ ] Ejecutar script de verificación en instancia privada
- [ ] Verificar que la instancia privada puede acceder a Internet
- [ ] Revisar logs iniciales en CloudWatch

### Auditoría Inicial
- [ ] Verificar que CloudTrail está registrando eventos
- [ ] Verificar que los logs aparecen en S3
- [ ] Revisar CloudWatch Log Groups creados
- [ ] Verificar que KMS está habilitado para EBS

---

## 🔄 Cambios Posteriores

### Antes de Modificar
```bash
# 1. Crear backup del estado actual
terraform state pull > terraform.tfstate.backup

# 2. Validar cambios
terraform validate
terraform plan -out=tfplan

# 3. Revisar el plan
terraform show tfplan
```

### Tipos de Cambios Seguros
✅ Cambios en tags
✅ Cambios en variables de configuración
✅ Agregar nuevas políticas IAM
✅ Cambios en CloudWatch alarms

### Cambios que Requieren Cuidado
⚠️ Cambios en CIDR blocks (requieren cambios en otras subredes)
⚠️ Eliminar Security Groups (puede afectar conectividad)
⚠️ Cambiar tipos de instancia (requiere redeploy)
⚠️ Desabilitar KMS (afecta volúmenes existentes)

---

## 🛡️ Mejoras de Seguridad Adicionales

### 1. Backend Remoto (Muy Recomendado)
```bash
# Crear bucket S3 para estado remoto
aws s3api create-bucket \
  --bucket mi-terraform-state \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Habilitar versionado
aws s3api put-bucket-versioning \
  --bucket mi-terraform-state \
  --versioning-configuration Status=Enabled

# Crear tabla DynamoDB para locks
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
```

Luego descomenta en `main.tf`:
```hcl
backend "s3" {
  bucket         = "mi-terraform-state"
  key            = "secure-arch/terraform.tfstate"
  region         = "eu-west-1"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

### 2. Escalabilidad (Auto Scaling)
Agregar a `instances.tf`:
```hcl
resource "aws_launch_template" "private_server" {
  # Configuración similar a aws_instance
}

resource "aws_autoscaling_group" "private_servers" {
  launch_template {
    id      = aws_launch_template.private_server.id
    version = "$Latest"
  }
  min_size         = 2
  max_size         = 4
  desired_capacity = 2
  # ... más configuración
}
```

### 3. Multi-AZ para Alta Disponibilidad
```hcl
# Crear subredes en múltiples AZs
availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
```

### 4. Alertas de Seguridad
```hcl
# CloudWatch Alarm para cambios en Security Groups
resource "aws_cloudwatch_metric_alarm" "security_group_changes" {
  alarm_name          = "${var.project_name}-sg-changes"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "${var.project_name}SGChanges"
  namespace           = "${var.project_name}/Security"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = ["arn:aws:sns:..."]  # Agregar SNS topic
}
```

---

## 📊 Monitoreo Continuo

### Métricas a Verificar Regularmente
```bash
# 1. Uso de CPU en instancias
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time 2025-02-01T00:00:00Z \
  --end-time 2025-02-06T00:00:00Z \
  --period 3600 \
  --statistics Average

# 2. Tráfico de red
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=InstanceId,Value=i-xxxxx \
  --start-time 2025-02-01T00:00:00Z \
  --end-time 2025-02-06T00:00:00Z \
  --period 3600 \
  --statistics Sum

# 3. Eventos de CloudTrail
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=CreateSecurityGroup \
  --max-results 10
```

### Logs a Revisar
- [ ] `/aws/cloudtrail/secure-cloud-arch` - Auditoría completa
- [ ] `/aws/ssm/secure-cloud-arch` - Sesiones SSM
- [ ] `/aws/vpc/flow-logs/secure-cloud-arch` - Tráfico de red

---

## 🚨 Incidentes de Seguridad

### Si sospechas compromiso de credenciales:
1. [ ] Revocar tokens/credenciales inmediatamente
2. [ ] Revisar CloudTrail para actividad sospechosa
3. [ ] Crear nuevas credenciales IAM
4. [ ] Auditar cambios en Security Groups y IAM policies
5. [ ] Considerar destruir y recrear la infraestructura

### Si cambios no autorizados en infraestructura:
1. [ ] Revisar CloudTrail para ver quién hizo cambios
2. [ ] Revertir cambios: `terraform apply -destroy` seguido de `terraform apply`
3. [ ] Auditar permisos IAM
4. [ ] Habilitar MFA enforcement

---

## 🔄 Mantenimiento Regular

### Semanal
- [ ] Revisar CloudTrail logs para anomalías
- [ ] Verificar métricas de CPU y memoria

### Mensual
- [ ] Revisar tamaño de CloudTrail S3 bucket
- [ ] Verificar costos estimados
- [ ] Auditar roles IAM y políticas
- [ ] Revisar actualizaciones de seguridad

### Trimestral
- [ ] Rotación de credenciales
- [ ] Actualizar Terraform y providers
- [ ] Revisar y actualizar scripts de setup
- [ ] Prueba de disaster recovery

---

## 📋 Eliminación Segura de Infraestructura

Cuando quieras destruir todo:

```bash
# 1. Backup del estado actual
terraform state pull > final-backup.json

# 2. Ver qué se eliminará
terraform destroy -dry-run

# 3. Eliminar
terraform destroy

# 4. Limpiar (opcional)
rm terraform.tfstate*
rm .terraform -rf
```

⚠️ **ADVERTENCIA**: La eliminación es irreversible. CloudTrail logs y snapshots de EBS podrían retenerse según políticas.

---

## 📞 Soporte y Recursos

- AWS Support: https://console.aws.amazon.com/support
- Terraform Issues: https://github.com/hashicorp/terraform/issues
- AWS Documentation: https://docs.aws.amazon.com

---

**Última revisión**: 2025-02-06
