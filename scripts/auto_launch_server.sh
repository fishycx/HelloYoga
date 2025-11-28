#!/bin/bash

# Auto-Launch Pimeier Server (Idempotent)
# This script checks if the Pimeier local server is running.
# If not, it launches it in a new Terminal window.

# Default port
PORT=8080

# Check if port is in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null ; then
    echo "✅ Pimeier Server is already running on port $PORT. Skipping launch."
    exit 0
fi

echo "🚀 Pimeier Server not running. Launching..."

# Get project root directory (assuming script is in PROJECT_ROOT/scripts/)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LAUNCH_SCRIPT="$PROJECT_ROOT/start_dev_server.sh"

# Verify launch script exists
if [ ! -f "$LAUNCH_SCRIPT" ]; then
    echo "❌ Error: start_dev_server.sh not found at $LAUNCH_SCRIPT"
    exit 1
fi

# Launch in new Terminal window (macOS specific)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Using osascript to execute terminal command cleanly
    osascript <<EOF
tell application "Terminal"
    do script "$LAUNCH_SCRIPT"
    activate
end tell
EOF
    echo "✅ Launched Pimeier Server in new Terminal."
else
    echo "⚠️  Auto-launch is only supported on macOS currently."
fi

