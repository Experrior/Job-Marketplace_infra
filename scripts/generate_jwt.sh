#!/bin/bash

random_value=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 128)

sed -i "s#JWT_SECRET:.*\$#JWT_SECRET: $random_value#g" compose.yaml

# todo add check if there are any remaining jwt_replace ?, probably not needed, unit test
