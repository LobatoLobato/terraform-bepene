#!/bin/bash

cd "$(dirname "$0")/.." || exit 1

IP_MAP_FILE="keys/ip_mappings.txt"

if [ ! -f "$IP_MAP_FILE" ]; then
    echo "No clients registered yet."
    exit 0
fi

echo "Client IP Assignments:"
echo "======================"
sort "$IP_MAP_FILE" | while read -r line; do
    IP=$(echo "$line" | cut -d' ' -f1)
    CLIENT=$(echo "$line" | cut -d' ' -f2)
    echo "$CLIENT -> $IP"
done
