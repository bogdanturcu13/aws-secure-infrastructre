# Secure Cloud Infrastructure - AWS

Infraestructura segura en AWS desplegada con Terraform, basada en **privilegio mínimo** y **Zero Trust**. Proyecto de aprendizaje con un coste mínimo (instancia NAT en lugar de NAT Gateway).

## Arquitectura

```
Internet
   │
[Internet Gateway]
   │
┌──┴───────────────── VPC 10.0.0.0/24 ──────────────────┐
│  Subred pública 10.0.0.0/25                           │
│    └─ Instancia NAT (EIP, source/dest check OFF)      │
│                          ▲                            │
│  Subred privada 10.0.0.128/25   0.0.0.0/0 → NAT       │
│    ├─ Servidor privado (sin IP pública, sin SSH)      │
│    └─ EFS (punto de montaje, NFS 2049)                │
└───────────────────────────────────────────────────────┘
```

| Componente | Detalle |
|---|---|
| Red | VPC, subred pública y privada, IGW y tablas de rutas separadas |
| Salida a Internet | Instancia NAT (iptables + masquerading), ruta por defecto de la subred privada hacia ella |
| Acceso | **AWS Systems Manager (Session Manager)**: sin SSH, sin claves, sin puertos de entrada |
| Cifrado | CMK de KMS (rotación anual) para volúmenes EBS, EFS y logs de CloudTrail |
| Almacenamiento | Volumen raíz cifrado de 15 GiB + EFS cifrado montado en `/mnt/efs` |
| Auditoría | CloudTrail multirregión con validación de logs, guardados en S3 |
| Costes | AWS Budget mensual con alerta por email |

### Grupos de seguridad

- **NAT**: entrada solo HTTP/HTTPS desde el servidor privado; salida libre.
- **Servidor privado**: **cero reglas de entrada**; salida HTTPS (443) y NFS hacia EFS.
- **EFS**: NFS (2049) solo desde el servidor privado.

## Estructura

```
terraform/
├── providers.tf    # Provider AWS y datos de la cuenta
├── variables.tf    # Variables (región, CIDRs, tamaños...)
├── network.tf      # VPC, subredes, IGW, rutas (incluida la ruta por la NAT)
├── security.tf     # Security groups, rol IAM e instance profile para SSM
├── compute.tf      # Instancias NAT y privada, IP elástica
├── kms.tf          # Clave gestionada por el cliente
├── efs.tf          # Sistema de archivos y punto de montaje
├── cloudtrail.tf   # Bucket S3 y trail de auditoría
├── budgets.tf      # Presupuesto mensual
├── outputs.tf      # Salidas
└── scripts/        # user_data de la NAT y del servidor privado
```

## Despliegue

Requisitos: Terraform ≥ 1.5, AWS CLI con credenciales configuradas y el [plugin de Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

## Conexión al servidor privado

```bash
terraform output ssm_connect_command
# aws ssm start-session --target i-xxxxxxxx --region eu-west-2
```

La instancia tarda unos minutos en aparecer como *Managed instance* en SSM: necesita que la NAT termine de configurarse para poder llegar a los endpoints de AWS.

## Comprobaciones

```bash
# Desde la sesión SSM en el servidor privado
curl -sI https://aws.amazon.com | head -n1   # sale a Internet a través de la NAT
df -h /mnt/efs                               # EFS montado
```

## Costes

Es un laboratorio, pero **no todo entra en la capa gratuita**: la CMK de KMS (~1 USD/mes), la IPv4 pública de la NAT y el EFS generan coste. Elimina todo al terminar:

```bash
terraform destroy
```

## Seguridad del repositorio

No se versionan `*.tfstate`, `*.tfvars`, claves (`*.ppk`, `*.pem`) ni los datos de diagnóstico de la cuenta. Revisa el `.gitignore` antes de añadir ficheros nuevos.

## Licencia

MIT
