#!/bin/bash
# Additional wait to make sure the application has started
sleep 10

# Try several times
for i in {1..6}; do
    echo “Try $i to validate the application...”
    
    # Try on port 80
    if curl -s http://localhost:80/health > /dev/null; then
        echo “The application is running on port 80”
        exit 0
    fi
    
    # Try on port 5000
    if curl -s http://localhost:5000/health > /dev/null; then
        echo “The application is running on port 5000”
        exit 0
    fi
    
    echo “The application is not responding, wait 10 seconds...”
    sleep 10
complete

# Check the logs in case of failure
echo “Application startup failed. Check the logs:”
cat /opt/confidant/flask.log
echo “Process status:”
ps aux | grep python3
echo “Port status:”
netstat -tulpn | grep -E ':80|:5000'

exit 1