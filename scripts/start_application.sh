#!/bin/bash

# Function for logging
log() {
    echo “$1” >> /opt/confidant/deploy.log
}

# Cleanup function
cleanup() {
    log “Cleaning up processes...”
    pkill -f “python3 app.py” || true
}

# Log the cleanup to be executed on exit
trap cleanup EXIT

# Move to the application directory
cd /opt/confidant

# Clean up previous processes
cleanup

# Set up the Flask environment
export FLASK_APP=/opt/confidant/app.py
export PYTHONPATH=/opt/confidant

# Configuring the registers
touch /opt/confidant/flask.log
touch /opt/confidant/deploy.log
chown ec2-user:ec2-user /opt/confidant/*.log

# Start the application
nohup python3 app.py > /opt/confidant/flask.log 2>&1 &
PID=$!

# Wait for initialization
sleep 5

# Check if the process is running
if ps -p $PID > /dev/null; then
    log “Application started successfully with PID: $PID”
    
    # Check if it is responding
    if curl -s http://localhost:80/health > /dev/null; then
        log “The application is responding correctly”
        # Close all file descriptors
        exec 1>&- 2>&-
        exit 0
    else
        log “The application process is running but is not responding”
        kill $PID
        exit 1
    fi else
else
    log “Application failed to start”
    exit 1
fi