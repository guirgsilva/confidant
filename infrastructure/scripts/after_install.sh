#!/bin/bash
set -e

cd /opt/confidant/app

echo "Current directory: $(pwd)"
echo "Directory contents:"
ls -la

# Check if the requirements.txt file exists
if [ ! -f requirements.txt ]; then
    echo "requirements.txt not found. Creating basic requirements..."
    echo "flask" > requirements.txt
fi

echo "Installing dependencies..."
# Installs the dependencies
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# Checks installation status
if [ $? -eq 0 ]; then
    echo "Dependencies installed successfully"
    # Ensure correct permissions after installation
    chown -R ec2-user:ec2-user /opt/confidant/app
    chmod -R 755 /opt/confidant/app
    exit 0
else
    echo "Failed to install dependencies"
    exit 1
fi