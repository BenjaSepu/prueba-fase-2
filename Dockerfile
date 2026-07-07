FROM python:3.11-slim

# Evitar que Python escriba archivos .pyc
ENV PYTHONDONTWRITEBYTECODE 1
# Deshabilitar buffer para que los logs de Ansible se muestren en tiempo real
ENV PYTHONUNBUFFERED 1

# Instalar dependencias del sistema operativo (necesarias para criptografía y ssh)
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-client \
    sshpass \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Instalar Ansible y librerías de Python para interacción con redes
RUN pip install --no-cache-dir ansible paramiko netmiko routeros-api

# Crear directorio de trabajo
WORKDIR /ansible

# Copiar los archivos de Ansible al contenedor
COPY . /ansible/

# Comando por defecto
CMD ["/bin/bash"]
