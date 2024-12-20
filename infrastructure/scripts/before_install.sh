#!/bin/bash
set -e

# Criar diretório de logs se não existir
sudo mkdir -p /opt/confidant/logs
sudo chown ec2-user:ec2-user /opt/confidant/logs

# Redirecionar logs para um arquivo que podemos acessar
exec 1> >(tee /opt/confidant/logs/before_install.log) 2>&1

echo "Starting BeforeInstall script..."
echo "Checking deployment archive directory..."
ls -la /opt/codedeploy-agent/deployment-root/*/d-*/deployment-archive/

echo "Current directory structure:"
ls -la /opt/confidant/ || echo "Confidant directory does not exist yet"

# Atualizar o sistema
echo "Updating system packages..."
sudo yum update -y || {
    echo "Failed to update system packages"
    exit 1
}

# Instalar dependências
echo "Installing Python and other dependencies..."
sudo yum install -y python3-pip python3-devel gcc || {
    echo "Failed to install Python dependencies"
    exit 1
}

# Criar estrutura de diretórios
echo "Creating application directory structure..."
sudo mkdir -p /opt/confidant/app
sudo mkdir -p /opt/confidant/scripts
sudo mkdir -p /opt/confidant/logs

# Configurar permissões
echo "Setting up permissions..."
sudo chown -R root:root /opt/confidant
sudo chmod -R 755 /opt/confidant
sudo chown -R ec2-user:ec2-user /opt/confidant/app
sudo chown -R ec2-user:ec2-user /opt/confidant/logs

# Verificar se o CodeDeploy agent está rodando
if ! systemctl is-active --quiet codedeploy-agent; then
    echo "CodeDeploy agent is not running. Attempting to start..."
    sudo systemctl start codedeploy-agent || {
        echo "Failed to start CodeDeploy agent"
        exit 1
    }
fi

echo "BeforeInstall script completed successfully"
exit 0
