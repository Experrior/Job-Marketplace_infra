#!/bin/bash

random_value=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 64)

sed -i "s#jwt_replace#$random_value#g" compose.yaml

# todo add check if there are any remaining jwt_replace ?, probably not needed, unit test
