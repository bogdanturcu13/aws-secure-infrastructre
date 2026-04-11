# Infraestructura Segura en AWS con Terraform

Este proyecto Terraform automatiza el despliegue de una arquitectura segura en AWS basada en principios de Zero Trust y privilegio mínimo.

## 📋 Requisitos Previos

- **Terraform**: v1.0 o superior
- **AWS CLI**: v2.x con credenciales configuradas
- **AWS Account**: Con permisos para crear VPC, EC2, IAM, KMS, S3, CloudTrail
- **Bash**: Para ejecutar los scripts de setup de instancias

## 🏗️ Estructura del Proyecto

```
├── main.tf                          # Configuración principal y providers
├── variables.tf                     # Declaración de variables
├── vpc.tf                           # VPC, subredes, tablas de rutas
├── security_groups.tf               # Grupos de seguridad
├── iam.tf                           # Roles y políticas IAM
├── kms.tf                           # Configuración de cifrado KMS
├── cloudtrail.tf                    # Auditoría con CloudTrail
├── instances.tf                     # Instancias EC2 (NAT y privada)
├── outputs.tf                       # Salidas del despliegue
├── nat_setup.sh                     # Script de configuración NAT
├── private_setup.sh                 # Script de configuración servidor privado
├── terraform.tfvars.example         # Archivo de ejemplo de variables
└── README.md                        # Este archivo
```

## 🚀 Cómo Desplegar

### 1. Preparar el entorno

```bash
# Clonar o descargar el proyecto
cd tu-proyecto-terraform

# Copiar el archivo de variables
cp terraform.tfvars.example terraform.tfvars

# (Opcional) Editar terraform.tfvars con tus valores específicos
nano terraform.tfvars
```

### 2. Inicializar Terraform

```bash
# Descargar providers y módulos necesarios
terraform init
```

### 3. Validar la configuración

```bash
# Validar sintaxis y estructura
terraform validate

# Mostrar un plan de los cambios a realizar
terraform plan -out=tfplan
```

### 4. Desplegar la infraestructura

```bash
# Aplicar la configuración (requiere confirmación)
terraform apply tfplan

# O aplicar directamente sin plan previo
terraform apply
```

Esto creará:
- ✅ VPC con subredes pública y privada
- ✅ Internet Gateway y tablas de enrutamiento
- ✅ Grupos de seguridad con acceso mínimo
- ✅ Instancia NAT en la subred pública
- ✅ Instancia privada Ubuntu en la subred privada
- ✅ Roles IAM y permisos SSM
- ✅ Cifrado KMS para volúmenes EBS
- ✅ CloudTrail para auditoría completa
- ✅ CloudWatch Log Groups

## 🔐 Acceso a la Instancia Privada

Una vez desplegado, accede a la instancia privada mediante AWS Session Manager:

```bash
# Obtener el ID de la instancia privada del output de Terraform
INSTANCE_ID=$(terraform output -raw private_server_details | jq -r '.instance_id')

# O directamente desde Terraform
terraform output ssm_access_command

# Ejecutar el comando SSM
aws ssm start-session --target <instance-id> --region eu-west-1
```

**Ventajas de SSM sobre SSH:**
- ✅ No requiere puerto SSH abierto (puerto 22 cerrado)
- ✅ Autenticación basada en IAM
- ✅ Toda la actividad registrada en CloudTrail y CloudWatch
- ✅ Control granular de permisos por usuario

## 📊 Auditoría y Logging

### CloudTrail
Todos los eventos de la infraestructura se registran en:
- **S3 Bucket**: Creado automáticamente para logs de CloudTrail
- **CloudWatch**: Log group en `/aws/cloudtrail/secure-cloud-arch`

Ver eventos:
```bash
# Filtrar cambios de Security Groups
aws logs filter-log-events \
  --log-group-name /aws/cloudtrail/secure-cloud-arch \
  --filter-pattern "AuthorizeSecurityGroupIngress"
```

### SSM Session Logs
Las sesiones SSM se registran en:
- **Log Group**: `/aws/ssm/secure-cloud-arch`
- **Cifrado**: Con la clave KMS de la cuenta

Ver logs de sesión:
```bash
aws logs tail /aws/ssm/secure-cloud-arch --follow
```

## 🔑 Administración de Claves KMS

La clave KMS se usa para cifrar:
- Volúmenes EBS
- Logs de CloudTrail
- Logs de CloudWatch

Ver detalles:
```bash
# Obtener el alias
terraform output -raw kms_configuration

# Ver rotación automática
aws kms describe-key --key-id alias/secure-cloud-arch-ebs
```

## ⚙️ Configuración de Variables

Edita `terraform.tfvars` para personalizar:

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| `aws_region` | Región de AWS | `eu-west-1` |
| `project_name` | Nombre del proyecto | `secure-cloud-arch` |
| `vpc_cidr` | CIDR de la VPC | `10.0.0.0/16` |
| `nat_instance_type` | Tipo de instancia NAT | `t3.micro` |
| `enable_cloudtrail` | Habilitar CloudTrail | `true` |
| `enable_vpc_flow_logs` | Habilitar VPC Flow Logs | `true` |

## 💰 Estimación de Costos

Con la configuración por defecto (instancias t3.micro):

| Servicio | Costo estimado/mes |
|----------|-------------------|
| EC2 NAT Instance (t3.micro) | ~$3-5 |
| EC2 Private Server (t3.micro) | ~$3-5 |
| KMS (custom key) | ~$1 |
| CloudTrail | Gratis (primero) |
| S3 (CloudTrail logs) | ~$0.50 |
| CloudWatch Logs | ~$1-2 |
| **Total estimado** | **~$9-15/mes** |

## 📝 Cambios y Actualizaciones

Para modificar la infraestructura:

```bash
# Editar el archivo correspondiente
nano vpc.tf  # para cambios de VPC

# Validar cambios
terraform validate

# Ver el plan de cambios
terraform plan

# Aplicar cambios
terraform apply
```

Para eliminar toda la infraestructura:

```bash
# ⚠️ Esto eliminará TODOS los recursos
terraform destroy
```

## 🔄 Estado de Terraform

El archivo `terraform.tfstate` contiene el estado actual. Es crítico:

### Proteger el estado

```bash
# Opción 1: Backend remoto en S3 (RECOMENDADO para producción)
# Descomentar la sección "backend" en main.tf y configurar

# Opción 2: Si usas estado local
# NUNCA commits terraform.tfstate a Git
echo "terraform.tfstate" >> .gitignore
echo "*.tfstate*" >> .gitignore
```

### Crear backend remoto S3 (opcional)

```bash
# Crear bucket y tabla DynamoDB para backend
aws s3api create-bucket \
  --bucket tu-bucket-terraform-state \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

# Habilitar versionado
aws s3api put-bucket-versioning \
  --bucket tu-bucket-terraform-state \
  --versioning-configuration Status=Enabled
```

## 🆘 Troubleshooting

### La instancia privada no puede conectarse a Internet

1. Verificar que la instancia NAT está en "running"
2. Verificar que la tabla de rutas privada apunta a la NAT
3. Verificar los Security Groups:

```bash
# Revisar reglas de NAT
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxx \
  --query 'SecurityGroups[0].IpPermissions'
```

### No puedo conectar por SSM

1. Verificar que la instancia tiene IAM Instance Profile:
```bash
aws ec2 describe-instances --instance-ids i-xxxxxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

2. Verificar que el SSM Agent está corriendo:
```bash
# Conectar por SSM y ejecutar:
systemctl status snap.amazon-ssm-agent.amazon-ssm-agent.service
```

3. Revisar la política IAM del rol de la instancia

### CloudTrail no registra eventos

Verificar que CloudTrail está habilitado y que el bucket S3 tiene permisos:

```bash
terraform output cloudtrail_configuration
```

## 📚 Documentación Adicional

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html)

## 📄 Licencia

Este proyecto está disponible bajo licencia MIT.

## 🤝 Contribuciones

Para mejorar este proyecto, por favor abre un issue o envía un pull request.

---

**Última actualización**: 2025-02-06
**Versión de Terraform**: 1.0+
**Versión de AWS Provider**: 5.x
