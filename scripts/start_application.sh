#!/bin/bash

# Move to the application directory
cd /opt/confidant

# Kill any existing application processes
pkill -f flask || true

# List the contents of the debug directory
echo “Contents of the current directory:”
ls -la

# Check if app.py exists
if [ ! -f “app.py” ]; then
    echo “app.py not found. Creating basic Flask application...”
    cat > app.py << 'EOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return “Hello, World!”

@app.route('/health')
def health():
    return “OK”, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80)
EOF
fi

# Set permissions
chown -R ec2-user:ec2-user /opt/confidant
chmod +x app.py

# Set up the Flask environment
export FLASK_APP=/opt/confidant/app.py
export PYTHONPATH=/opt/confidant

# Configuring the registers
tap /opt/confidant/flask.log
chown ec2-user:ec2-user /opt/confidant/flask.log

# Start the application with full path
cd /opt/confidant && /usr/local/bin/flask run --host=0.0.0.0 --port=80 > /opt/confidant/flask.log 2>&1 &

# Captures the PID
PID=$!

# Wait for the application to start
sleep 10

# Check if the process is running
if ps -p $PID > /dev/null; then
    echo “Application started successfully with PID: $PID”
    # Try making a request to check if it is responding
    if curl -s http://localhost:80/health > /dev/null; then
        echo “The application is responding correctly”
        exit 0
    else
        echo “The application process is running but is not responding to requests”
        echo “Flask logs:”
        cat /opt/confidant/flask.log
        exit 1
    fi
else
    echo “Application failed to start. Logs:”
    cat /opt/confidant/flask.log
    exit 1
fi