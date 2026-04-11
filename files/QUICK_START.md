# 🚀 Quick Start - Despliegue en 5 Minutos

## Paso 1: Preparación (1 minuto)

```bash
# Verificar que tienes todo instalado
terraform version        # Debe ser >= 1.0
aws --version            # Debe ser >= 2.0
aws sts get-caller-identity  # Verificar que estás autenticado

# Clonar/descargar los archivos
cd tu-directorio-terraform
```

## Paso 2: Configuración (2 minutos)

```bash
# Crear archivo de variables
cp terraform.tfvars.example terraform.tfvars

# Editar valores (opcional, los defaults están bien para prueba)
nano terraform.tfvars

# Cambiar minimamente:
# - aws_region: tu región (ej: eu-west-1)
# - project_name: nombre único (ej: secure-arch-tuempresa)
```

## Paso 3: Despliegue (2 minutos)

```bash
# Inicializar Terraform
terraform init

# Ver plan de cambios (opcional pero recomendado)
terraform plan

# Desplegar (requiere escribir "yes")
terraform apply
```

## ✅ Listo

Al terminar verás los outputs con:
- IDs de instancias
- Comando para conectar por SSM
- Información de seguridad

---

## 📝 Conectar a la Instancia Privada

Una vez desplegado (5-10 minutos para que las instancias inicien):

```bash
# Opción A: Usar el output directo
terraform output ssm_access_command
# Copia y ejecuta el comando

# Opción B: Manual
INSTANCE_ID=$(terraform output -json private_server_details | jq -r '.instance_id')
aws ssm start-session --target $INSTANCE_ID --region eu-west-1
```

---

## 🔍 Verificaciones Básicas

```bash
# Ver IPs de instancias
terraform output nat_instance_details
terraform output private_server_details

# Ver estado de instancias
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=secure-cloud-arch" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name,PrivateIpAddress]'

# Ver logs de CloudTrail
aws logs tail /aws/cloudtrail/secure-cloud-arch --follow
```

---

## ⚠️ Si Algo Falla

```bash
# Revisar logs de usuario de instancias
aws ec2 get-console-output --instance-id i-xxxxxxxx

# Ver errores de Terraform
terraform show
terraform state show

# Destruir y reintentar
terraform destroy  # (cuando estés seguro)
terraform apply
```

---

## 💰 Costos Estimados

**~$10-15 USD/mes** con configuración default:
- 2 instancias t3.micro
- Almacenamiento EBS
- CloudTrail y CloudWatch

---

## 🔐 Información de Seguridad

| Aspecto | Estado |
|--------|--------|
| SSH (puerto 22) | ❌ Cerrado |
| Acceso | ✅ SSM (IAM-based) |
| EBS Encryption | ✅ KMS CMK |
| Auditoría | ✅ CloudTrail |
| Logs cifrados | ✅ KMS |
| Security Groups | ✅ Minimal access |

---

## 📚 Documentación Completa

- `README.md` - Guía detallada
- `SECURITY_CHECKLIST.md` - Checklist de seguridad
- Archivos `.tf` - Código comentado de cada componente

---

## 🧹 Limpiar

Cuando termines (eliminará TODO):

```bash
# ⚠️ Esto es irreversible
terraform destroy
```

---

**¡Listo!** Tu infraestructura segura está desplegada 🎉
