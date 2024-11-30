#!/bin/bash

# Move para o diretório da aplicação
cd /opt/confidant/app

# Mata processos anteriores
pkill -f "app.py" || true

# Configura o ambiente
export FLASK_APP=/opt/confidant/app/app.py
export PYTHONPATH=/opt/confidant/app

# Configura logs
touch /opt/confidant/app/flask.log
chown ec2-user:ec2-user /opt/confidant/app/flask.log

# Inicia a aplicação
nohup python3 app.py > /opt/confidant/app/flask.log 2>&1 &
PID=$!

# Aguarda inicialização
sleep 5

# Verifica status
if ps -p $PID > /dev/null; then
    echo "Application started successfully with PID: $PID"
    
    if curl -s http://localhost:80/health > /dev/null; then
        echo "Application is responding correctly"
        exit 0
    else
        echo "Application process is running but not responding"
        kill $PID
        exit 1
    fi
else
    echo "Application failed to start"
    cat /opt/confidant/app/flask.log
    exit 1
fi