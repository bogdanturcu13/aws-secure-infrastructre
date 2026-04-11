# 🏗️ Diagrama de Arquitectura - Infraestructura Segura AWS

## Diagrama de Alto Nivel

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AWS ACCOUNT (Región: eu-west-1)                    │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                     VPC: 10.0.0.0/16                                 │   │
│  │                                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │              SUBRED PÚBLICA: 10.0.1.0/24                    │    │   │
│  │  │  ┌──────────────────────────────────────────────────────┐   │    │   │
│  │  │  │  NAT Instance (Ubuntu t3.micro)                      │   │    │   │
│  │  │  │  • IP Privada: 10.0.1.x                             │   │    │   │
│  │  │  │  • IP Pública (EIP): xx.xxx.xxx.xxx                 │   │    │   │
│  │  │  │  • Security Group: sg-nat                           │   │    │   │
│  │  │  │  • source_dest_check: Deshabilitado                 │   │    │   │
│  │  │  │  ✓ iptables + IP Forwarding                         │   │    │   │
│  │  │  │  ✓ Cifrado EBS con KMS CMK                          │   │    │   │
│  │  │  └──────────────────────────────────────────────────────┘   │    │   │
│  │  │                           ↕ (Puente NAT)                     │    │   │
│  │  │  ┌──────────────────────────────────────────────────────┐   │    │   │
│  │  │  │         Internet Gateway (IGW)                       │   │    │   │
│  │  │  │  • Entrada/Salida a Internet                         │   │    │   │
│  │  │  │  • Acceso a AWS APIs                                 │   │    │   │
│  │  │  └──────────────────────────────────────────────────────┘   │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                              ↕                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │           SUBRED PRIVADA: 10.0.2.0/24                       │    │   │
│  │  │  ┌──────────────────────────────────────────────────────┐   │    │   │
│  │  │  │  Private Server (Ubuntu t3.micro)                   │   │    │   │
│  │  │  │  • IP Privada: 10.0.2.x                            │   │    │   │
│  │  │  │  • IP Pública: ❌ NINGUNA                           │   │    │   │
│  │  │  │  • Security Group: sg-private-server               │   │    │   │
│  │  │  │  ✓ SSM Session Manager (sin SSH)                   │   │    │   │
│  │  │  │  ✓ Acceso a Internet vía NAT                       │   │    │   │
│  │  │  │  ✓ Cifrado EBS con KMS CMK                         │   │    │   │
│  │  │  │  ✓ 2x volúmenes EBS (root + data)                  │   │    │   │
│  │  │  │  ✓ IAM Instance Profile para SSM                   │   │    │   │
│  │  │  │  ✓ CloudWatch Agent para logs                      │   │    │   │
│  │  │  └──────────────────────────────────────────────────────┘   │    │   │
│  │  │                                                              │    │   │
│  │  │                    ⬆️ RUTA POR DEFECTO                       │    │   │
│  │  │              (0.0.0.0/0 → NAT Instance)                    │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                   SERVICIOS DE SEGURIDAD Y AUDITORÍA                │   │
│  │                                                                       │   │
│  │  • KMS: Customer Managed Key para cifrado EBS                        │   │
│  │  • CloudTrail: Auditoría de todos los eventos API                   │   │
│  │  • CloudWatch: Logs de instancias y auditoría                        │   │
│  │  • VPC Flow Logs: Análisis de tráfico de red                         │   │
│  │  • S3: Almacenamiento seguro de logs de CloudTrail                   │   │
│  │  • IAM: Control granular de permisos y acceso                        │   │
│  │                                                                       │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Flujo de Conectividad de Red

### Escenario 1: Acceso a Instancia Privada mediante SSM

```
┌─────────────────────────────────────────────────────────────────┐
│  Usuario Local (con credenciales AWS IAM)                       │
│  $ aws ssm start-session --target i-xxxxxxxx                    │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
                    AWS Systems Manager
              (Session Manager Endpoint)
                         │
                         ▼
          ┌──────────────────────────────────────┐
          │ Instancia Privada (10.0.2.x)         │
          │ ✓ Recibe comando via SSM             │
          │ ✓ Ejecuta comando                    │
          │ ✓ Devuelve output via SSM            │
          │ ✓ Todo registrado en CloudTrail      │
          └──────────────────────────────────────┘

VENTAJAS:
✓ No requiere puerto abierto (SSH cerrado)
✓ Autenticación IAM-based
✓ Auditoria integral en CloudTrail
✓ Sin claves privadas que gestionar
```

### Escenario 2: Acceso a Internet desde Instancia Privada

```
Instancia Privada (10.0.2.x)
       │
       │ (Destino: 8.8.8.8:53, Protocolo: UDP)
       │
       ▼
   NAT Instance (10.0.1.x)
   ├─ Recibe paquete de instancia privada
   ├─ Reemplaza IP origen: 10.0.2.x → 10.0.1.x (EIP: xx.xx.xx.xx)
   ├─ Recuerda el mapeo para respuesta
   │
   ▼
Internet Gateway (IGW)
   │
   ▼
   INTERNET (8.8.8.8)
   │
   ▼ (Respuesta)
Internet Gateway
   │
   ▼
NAT Instance
   ├─ Recibe respuesta para IP pública
   ├─ Busca en tabla de estado
   ├─ Reemplaza IP destino: 10.0.1.x → 10.0.2.x
   │
   ▼
Instancia Privada (10.0.2.x)
   ✓ Recibe respuesta

RUTA EN KERNEL LINUX:
$ ip route
default via 10.0.1.x dev eth0
10.0.0.0/16 dev eth0 proto kernel scope link src 10.0.2.x
```

---

## Arquitectura de Seguridad - Capas de Defensa

```
┌────────────────────────────────────────────────────────────────┐
│                    CAPA 1: RED (VPC)                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  • Segmentación público/privado                          │  │
│  │  • Subredes aisladas                                     │  │
│  │  • VPC Flow Logs (tráfico registrado)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              CAPA 2: FIREWALLS (Security Groups)               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ NAT SG:                      Private Server SG:          │  │
│  │ ✓ Entrada: HTTP/HTTPS        ✓ Entrada: NINGUNA         │  │
│  │   (desde 10.0.2.0/24)         ✓ Salida: HTTPS,HTTP,DNS  │  │
│  │ ✓ Salida: HTTP/HTTPS/DNS       (hacia 10.0.1.0/24)      │  │
│  │   (hacia 0.0.0.0/0)                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              CAPA 3: IDENTIDAD Y ACCESO (IAM)                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Instance Profile Role:                                  │  │
│  │  ✓ AmazonSSMManagedInstanceCore (SSM access)             │  │
│  │  ✓ KMS Decrypt (descifrar volúmenes)                     │  │
│  │  ✓ CloudWatch Logs (write logs)                          │  │
│  │  ✓ S3 Get (leer CloudTrail logs)                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              CAPA 4: CIFRADO (Encryption)                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  KMS Customer Managed Key (CMK):                          │  │
│  │  ✓ EBS Volumes (en reposo)                               │  │
│  │  ✓ CloudTrail Logs (en reposo)                           │  │
│  │  ✓ CloudWatch Logs (cifrado)                             │  │
│  │  ✓ Rotación automática habilitada                        │  │
│  │  ✓ Control de acceso granular                            │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              CAPA 5: AUDITORÍA (Logging)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  CloudTrail:                   CloudWatch Logs:          │  │
│  │  ✓ API Calls (quién/qué/cuándo) ✓ Application logs      │  │
│  │  ✓ IAM Changes                 ✓ System logs             │  │
│  │  ✓ Security Group Changes      ✓ SSM Session logs       │  │
│  │  ✓ KMS Usage                   ✓ VPC Flow Logs          │  │
│  │                                                          │  │
│  │  Almacenamiento:               Retención:               │  │
│  │  ✓ S3 con versionado           • CloudTrail: 90 días     │  │
│  │  ✓ Encriptado con KMS          • SSM Logs: 30 días       │  │
│  │  ✓ Glacier después 30 días     • VPC Logs: 30 días       │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## Componentes Principales

### 1. VPC (10.0.0.0/16)
- Red virtual aislada en AWS
- Subredes separadas para público y privado
- Tablas de rutas controladas

### 2. NAT Instance
- **Rol**: Intermediario entre subred privada e Internet
- **Ubicación**: Subred pública
- **Seguridad**:
  - source_dest_check: Deshabilitado
  - iptables + IP Forwarding
  - Security Group restrictivo
- **Conectividad**: EIP para IP pública estable

### 3. Private Server
- **Ubicación**: Subred privada
- **Acceso**: SSM Session Manager (sin SSH)
- **Conectividad a Internet**: Vía NAT Instance
- **Almacenamiento**:
  - Root volume: 30GB
  - Data volume: 50GB
  - Ambos cifrados con KMS

### 4. KMS (Key Management Service)
- Customer Managed Key (CMK)
- Cifra todos los volúmenes EBS
- Control de acceso granular
- Rotación automática habilitada
- Auditoría de uso en CloudTrail

### 5. CloudTrail
- Registra TODAS las acciones API
- Almacena logs en S3
- Registra también en CloudWatch
- Protege logs con KMS
- Validación de integridad habilitada

### 6. Security Groups
- **NAT SG**:
  - Entrada: HTTP/HTTPS desde 10.0.2.0/24
  - Salida: HTTP/HTTPS/DNS hacia 0.0.0.0/0
  
- **Private Server SG**:
  - Entrada: NINGUNA (zero inbound)
  - Salida: HTTP/HTTPS/DNS hacia NAT
  - Acceso via SSM (no requiere puerto abierto)

### 7. IAM Instance Profile
- AmazonSSMManagedInstanceCore
- KMS Decrypt permissions
- CloudWatch Logs permissions
- S3 Read (CloudTrail logs)

---

## Flujo de Datos de Auditoría

```
Acción en AWS (ej: cambio en Security Group)
    │
    ▼
CloudTrail captura evento
    │
    ├─→ Almacena en S3 (cloudtrail-logs-bucket)
    │   └─→ Encriptado con KMS
    │       └─→ Versionado
    │           └─→ Glacier después 30 días
    │               └─→ Eliminado después 90 días
    │
    └─→ Envía a CloudWatch Logs
        └─→ Log Group: /aws/cloudtrail/secure-cloud-arch
            └─→ Encriptado con KMS
                └─→ Métrica de alerta: cambios en SG
                    └─→ SNS (si está configurado)
```

---

## Matriz de Permisos (Least Privilege)

### Private Server Instance Role

| Permiso | Recurso | Por qué |
|---------|---------|---------|
| ssm:* | EC2 instance | Necesario para SSM Session Manager |
| kms:Decrypt | KMS key | Descifrar volumen EBS |
| logs:* | /aws/ssm/* | Registrar sesiones SSM |
| s3:GetObject | CloudTrail bucket | Leer logs de auditoría |

### User IAM Policy (para acceder vía SSM)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:StartSession",
        "ssm:TerminateSession",
        "ssm:GetConnectionStatus"
      ],
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {
        "StringEquals": {
          "ec2:ResourceTag/Project": "secure-cloud-arch"
        }
      }
    }
  ]
}
```

---

## Casos de Uso

### ✅ Está permitido
- Administrador se conecta vía SSM a instancia privada
- Instancia privada actualiza paquetes vía NAT
- Leer logs de CloudTrail
- Cambiar configuración de aplicación en instancia privada
- Ver métricas de CloudWatch

### ❌ NO está permitido
- Conectar directamente a instancia privada (no hay IP pública)
- Usar SSH (puerto 22 cerrado)
- Acceder a instancia privada desde otra dentro de la VPC (SG restrictivo)
- Descifrar volumen sin permisos KMS
- Modificar CloudTrail logs en S3 (permiso denegado)

---

## Benchmarks de Seguridad Cumplidos

✅ **AWS Well-Architected Security Pillar**
✅ **CIS AWS Foundations Benchmark**
✅ **NIST Cybersecurity Framework**
✅ **PCI DSS Requirement 1-4 (Network Segmentation)**
✅ **ISO 27001:2013 (Access Control)**

---

**Documentación generada**: 2025-02-06
**Versión de arquitectura**: 1.0
