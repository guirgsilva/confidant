#!/bin/bash

# Espera a aplicação iniciar completamente
sleep 5

# Tenta até 3 vezes
for i in {1..3}; do
    echo "Attempt $i to validate service..."
    
    # Verifica se a aplicação está respondendo
    if curl -s http://localhost:80/health > /dev/null; then
        echo "Application is running and responding"
        exit 0
    fi
    
    echo "Service not responding, waiting 5 seconds..."
    sleep 5
done

# Se chegou aqui, falhou todas as tentativas
echo "Service validation failed after 3 attempts"
echo "Checking service status:"
ps aux | grep python3
echo "Checking application logs:"
cat /opt/confidant/app/flask.log
exit 1