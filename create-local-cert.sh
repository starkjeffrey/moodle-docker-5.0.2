#!/bin/bash

# Create self-signed certificate for local development
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout traefik/certs/moodle.local.key \
  -out traefik/certs/moodle.local.crt \
  -subj "/C=US/ST=State/L=City/O=Local Dev/CN=moodle.local" \
  -addext "subjectAltName=DNS:moodle.local,DNS:*.moodle.local"

echo "Certificate created for moodle.local"
echo "Add this to /etc/hosts:"
echo "127.0.0.1 moodle.local"