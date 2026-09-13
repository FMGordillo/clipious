#!/usr/bin/env bash
# Helper script to ensure devenv services (postgres, invidious) are running before executing a hook.
# This is called by pre-commit hooks to start services on-demand, only if needed.
# 
# Usage: check-services.sh [command...]
#   If command is provided, it will be executed after services are ready.
#   If no command, just ensure services are ready and exit.

set -e

# Check if postgres is running by attempting a connection
is_postgres_running() {
  pg_isready -h 127.0.0.1 -p 5433 -q 2>/dev/null && return 0 || return 1
}

# Check if invidious is running by checking if it's listening on its default port
is_invidious_running() {
  nc -z 127.0.0.1 3000 2>/dev/null && return 0 || return 1
}

# Start devenv services in the background if they're not running
# This spawns `devenv up` which will block and start all configured services
ensure_services_running() {
  if ! is_postgres_running; then
    # Get the DEVENV_ROOT to find where we are
    if [ -z "$DEVENV_ROOT" ]; then
      echo "Error: DEVENV_ROOT not set. Make sure you're running from within a 'devenv shell'." >&2
      return 1
    fi
    
    echo "Starting devenv services (PostgreSQL, Invidious)..." >&2
    
    # Start services in background, but give it a short timeout to establish them
    # We'll wait for postgres to be ready before continuing
    (cd "$DEVENV_ROOT" && devenv up > /tmp/devenv-services.log 2>&1) &
    local devenv_pid=$!
    
    # Wait for postgres to be ready (max 30 seconds)
    local attempt=0
    local max_attempts=60  # 60 * 0.5s = 30 seconds
    while [ $attempt -lt $max_attempts ]; do
      if is_postgres_running; then
        echo "Services ready." >&2
        return 0
      fi
      sleep 0.5
      ((attempt++))
    done
    
    echo "Error: Services failed to start within 30 seconds. Check /tmp/devenv-services.log" >&2
    return 1
  fi
}

# Main logic
ensure_services_running || exit 1

# If a command was provided, execute it
if [ $# -gt 0 ]; then
  exec "$@"
fi
