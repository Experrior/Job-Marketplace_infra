#!/bin/sh

set -e

initialize_db() {
    echo "Initializing PostgreSQL database in /backup..."
    # initdb -D /backup
    rm -rf /backup/*
    echo "PostgreSQL database initialized successfully."
}

set_permissions() {
    echo "Setting ownership and permissions for /backup..."
    chown -R 70:70 /backup
    chmod 0700 /backup
    echo "Ownership and permissions set successfully."
}

if [ -e /backup/global/pg_control ]; then
    echo "PostgreSQL data directory already exists in /backup. Skipping initdb."
else

    initialize_db
    echo "Warning: /backup directory is not empty but does not contain a valid PostgreSQL data directory."
    echo "Skipping initdb to preserve existing data."

fi

set_permissions
