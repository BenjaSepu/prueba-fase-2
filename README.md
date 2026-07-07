# Proyecto de Automatización VPN Full-Mesh (IPSec/GRE/OSPF)

Este repositorio contiene la solución completa de automatización de redes utilizando Ansible para configurar una topología Full-Mesh entre 3 routers MikroTik CHR, integrada con un pipeline de Integración Continua y Despliegue Continuo (CI/CD) a través de **GitHub Actions** y **GitLab CI**.

---

## 📋 Arquitectura de la Solución
El proyecto establece conectividad segura y enrutamiento dinámico automatizando la configuración de:
1. **Underlay (Físico)**: Direccionamiento IP en enlaces físicos punto a punto.
2. **Overlay (GRE)**: Túneles GRE para crear la topología lógica Full-Mesh.
3. **Seguridad (IPSec)**: Cifrado del tráfico GRE utilizando claves pre-compartidas (IPSec Secret) nativas de MikroTik.
4. **Enrutamiento Dinámico (OSPFv3/v7)**: Distribución de las redes Loopback a través de los túneles seguros.

---

## 📂 Estructura del Proyecto
```text
├── ansible.cfg              # Configuración base de Ansible (desactiva host_key_checking y define .vault_pass)
├── .github/workflows/
│   ├── early-testing.yml    # Pipeline 1: Detección temprana en ramas secundarias (Linting/Sintaxis)
│   ├── ci.yml               # Pipeline 2: Integración Continua (Lint/Build/Dry-run en Main/Master)
│   └── deploy.yml           # Pipeline 3: Despliegue Continuo (Despliegue real en Main/Master)
├── .gitlab-ci.yml           # Configuración equivalente para GitLab CI/CD (Multi-stage + manual gate)
├── inventory/
│   └── hosts.yml            # Inventario dinámico con variables de entorno para credenciales
├── group_vars/
│   └── routers.yml          # Variables globales (IPSec Secret encriptado con Ansible Vault y OSPF Area)
├── host_vars/
│   ├── R1.yml               # Variables específicas de R1 (Interfaces y GRE)
│   ├── R2.yml               # Variables específicas de R2 (Interfaces y GRE)
│   └── R3.yml               # Variables específicas de R3 (Interfaces y GRE)
├── roles/
│   ├── base_config/         # Rol: Loopbacks, Hostname e IPs físicas (Underlay)
│   ├── gre_tunnel/          # Rol: Interfaces GRE con IPSec secreto dinámico (Overlay)
│   └── ospf_routing/        # Rol: Instancias, Áreas y Templates OSPF (Enrutamiento)
├── site.yml                 # Playbook principal que orquesta todos los roles
├── Dockerfile               # Entorno Docker con Python, Ansible y dependencias de red
├── docker-compose.yml       # Orquestación del contenedor local
└── .vault_pass              # Archivo local con la contraseña del Vault (Ignorado en Git)
```

---

## 🔒 Fase 1: Proyecto Ansible & Seguridad de Datos (Ansible Vault)
Las credenciales y secretos del proyecto no se almacenan en texto plano:

### 1. Encriptación del IPSec Secret
El archivo `group_vars/routers.yml` contiene la clave IPSec encriptada utilizando **Ansible Vault**:
```yaml
ipsec_secret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          31333231616365623563633030623937326661306433626566653833343265353730663630363134...
```
* La contraseña por defecto del Vault para pruebas locales es: `inacap2026`.

### 2. Ejecución Local con Ansible Vault
Para ejecutar el playbook localmente descifrando las variables:
1. Crea un archivo `.vault_pass` en la raíz del proyecto que contenga la contraseña:
   ```bash
   echo "inacap2026" > .vault_pass
   ```
2. Ejecuta el playbook (se leerá la clave automáticamente desde `.vault_pass` gracias a `ansible.cfg`):
   ```bash
   ansible-playbook site.yml
   ```
   *(Nota: Puedes pasar la contraseña de administración de los routers mediante la variable `ANSIBLE_PASSWORD`)*:
   ```bash
   ANSIBLE_PASSWORD="TuPasswordAdmin" ansible-playbook site.yml
   ```

---

## 🚀 Fase 2: Integración de CI/CD (GitHub Actions / GitLab CI)
El pipeline automatiza la verificación y despliegue del proyecto asegurando que no se suba código roto ni credenciales expuestas.

### ⚙️ 1. Configuración de Runners Locales (Self-Hosted)
Dado que los routers CHR corren en un entorno local (como GNS3 en tu laptop), el Runner de CI/CD debe ejecutarse en tu máquina para tener conectividad IP directa a la red.

#### Para GitHub Actions:
1. Ve a tu repositorio en GitHub y navega a **Settings > Actions > Runners**.
2. Haz clic en **New self-hosted runner** y selecciona tu sistema operativo (Linux/macOS/Windows).
3. Sigue las instrucciones en la consola para descargar, configurar y registrar el runner.
4. Cuando te pregunte por las etiquetas (tags), puedes dejar las predeterminadas. Los playbooks buscarán el runner con la etiqueta `self-hosted`.
5. Inicia el runner:
   ```bash
   ./run.sh
   ```

#### Para GitLab CI:
1. Instala GitLab Runner en tu máquina.
2. Registra el runner apuntando a tu instancia de GitLab:
   ```bash
   sudo gitlab-runner register
   ```
3. Introduce el Token de registro que se encuentra en **Settings > CI/CD > Runners** en GitLab.
4. Elige el executor `shell` o `docker` según prefieras (si eliges `shell`, asegúrate de tener `ansible` y python instalados en el host).

---

### 🔑 2. Configuración de Secretos en el Repositorio (GitHub Secrets / GitLab Variables)
Para que los pipelines funcionen correctamente de forma segura, debes añadir los siguientes secretos:

| Nombre del Secreto / Variable | Descripción | Valor de Ejemplo |
| :--- | :--- | :--- |
| `ANSIBLE_VAULT_PASSWORD` | Contraseña para descifrar archivos encriptados en Git (como `routers.yml`) | `inacap2026` |
| `ANSIBLE_PASSWORD` | Contraseña de administración de los routers MikroTik | `admin` (o tu clave personalizada) |
| `DISCORD_WEBHOOK_URL` | *(Opcional)* URL de webhook para recibir alertas del pipeline en Discord/Slack | `https://discord.com/api/webhooks/...` |

---

### 🔄 3. Funcionamiento de los Pipelines de CI/CD

#### Flujo de Trabajo en GitHub Actions:
* **Pipeline de Detección Temprana (`early-testing.yml`)**:
  * Se ejecuta en cualquier rama que **no sea** `main` o `master` y en todos los Pull Requests.
  * Realiza análisis estático con `yamllint`, verifica mejores prácticas con `ansible-lint` y realiza un chequeo de sintaxis estricto (`--syntax-check`).
* **Pipeline de Integración Continua (`ci.yml`)**:
  * Se ejecuta al empujar cambios o abrir PRs a las ramas principales.
  * Corre análisis estático, construye la imagen Docker del entorno de automatización y realiza una simulación de despliegue en modo prueba (`--check`).
* **Pipeline de Despliegue Continuo (`deploy.yml`)**:
  * Se ejecuta **únicamente** cuando se fusiona o empuja código a `main` o `master`.
  * Aplica los cambios de forma definitiva y en tiempo real a los routers MikroTik locales.

#### Flujo de Trabajo en GitLab CI (`.gitlab-ci.yml`):
El pipeline está dividido en 4 Stages secuenciales:
1. **Lint**: Validación de archivos yaml y sintaxis del playbook.
2. **Build**: Empaquetado y build de la imagen Docker de red.
3. **Test Dry-Run**: Simulación del despliegue en modo check.
4. **Deploy**: Aplicación real en los routers, configurado como **manual** (`when: manual`) para requerir aprobación humana antes de alterar la red de producción.

---

### 🔔 4. Observabilidad y Monitoreo (Notificaciones)
Ambos pipelines cuentan con soporte para notificaciones webhooks en tiempo real. Si configuras la variable `DISCORD_WEBHOOK_URL`, recibirás una alerta de color (verde para éxito, rojo para fallo) directamente en tu canal de comunicación preferido detallando el estado de la compilación, autor del commit, ID de ejecución y enlace directo a los logs para una depuración rápida.
