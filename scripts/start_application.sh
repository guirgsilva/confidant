#!/bin/bash

# Move para o diretório da aplicação
cd /opt/confidant

# Mata qualquer processo existente da aplicação
pkill -f flask || true

# Lista o conteúdo do diretório para debug
echo "Current directory contents:"
ls -la

# Verifica se app.py existe e tem o conteúdo correto
echo "from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return 'Hello, World!'

@app.route('/health')
def health():
    return 'OK', 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)" > app.py

# Configura permissões
chown -R ec2-user:ec2-user /opt/confidant
chmod 755 app.py

# Configura o ambiente Flask
export FLASK_APP=/opt/confidant/app.py
export PYTHONPATH=/opt/confidant

# Configura logs
touch /opt/confidant/flask.log
chown ec2-user:ec2-user /opt/confidant/flask.log

# Tenta iniciar a aplicação usando python diretamente
python3 -c "import sys; print(sys.version)"
cd /opt/confidant && python3 app.py > /opt/confidant/flask.log 2>&1 &

# Captura o PID
PID=$!

# Espera a aplicação iniciar
sleep 10

# Verifica se o processo está rodando
if ps -p $PID > /dev/null; then
    echo "Application started successfully with PID: $PID"
    # Tenta fazer uma requisição para verificar se está respondendo
    if curl -s http://localhost:80/health > /dev/null; then
        echo "Application is responding correctly"
        exit 0
    else
        echo "Application process is running but not responding to requests"
        echo "Flask logs:"
        cat /opt/confidant/flask.log
        exit 1
    fi
else
    echo "Application failed to start. Logs:"
    cat /opt/confidant/flask.log
    echo "Python version:"
    python3 --version
    echo "Flask version:"
    pip3 list | grep Flask
    exit 1
fi