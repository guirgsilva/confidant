#!/bin/bash
# Preparar ambiente
yum update -y
yum install -y python3-pip python3-devel gcc
mkdir -p /opt/confidant
chmod 755 /opt/confidant