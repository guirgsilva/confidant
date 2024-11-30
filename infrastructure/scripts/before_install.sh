#!/bin/bash
# Preparar ambiente
yum update -y
yum install -y python3-pip python3-devel gcc

# Create application directory structure
mkdir -p /opt/confidant/app
chmod 755 /opt/confidant
chmod 755 /opt/confidant/app