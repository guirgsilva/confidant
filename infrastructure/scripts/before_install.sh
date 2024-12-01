#!/bin/bash
set -e

# Habilitar logs detalhados
exec 1> >(tee /var/log/before_install.log) 2>&1

echo "Starting BeforeInstall script..."

# Atualizar o sistema
echo "Updating system packages..."
yum update -y || {
    echo "Failed to update system packages"
    exit 1
}

# Instalar dependências
echo "Installing Python and other dependencies..."
yum install -y python3-pip python3-devel gcc || {
    echo "Failed to install Python dependencies"
    exit 1
}

# Criar estrutura de diretórios
echo "Creating application directory structure..."
mkdir -p /opt/confidant/app
mkdir -p /opt/confidant/scripts
mkdir -p /opt/confidant/logs

# Configurar permissões
echo "Setting up permissions..."
chown -R root:root /opt/confidant
chmod -R 755 /opt/confidant
chown -R ec2-user:ec2-user /opt/confidant/app
chown -R ec2-user:ec2-user /opt/confidant/logs

# Verificar se o CodeDeploy agent está rodando
if ! systemctl is-active --quiet codedeploy-agent; then
    echo "CodeDeploy agent is not running. Attempting to start..."
    systemctl start codedeploy-agent || {
        echo "Failed to start CodeDeploy agent"
        exit 1
    }
fi

echo "BeforeInstall script completed successfully"
exit 0