#!/bin/bash

set -ex

log_file="../logs/git_check_update_logs.txt"
backend_dir="../Job-Marketplace_backend"

cd "${backend_dir}"
while true; do


    # stupid workaround, for duplicate ssh keys for same github host
    #ssh-agent bash -c "ssh-add ~/.ssh/id_rsa_backend; git reset --hard origin/feature/user_service_mateusz" |>

        git fetch origin
        if git diff --quiet HEAD origin/main ; then
                echo 'ni ma'
        else
                echo 'jest'
                git pull origin
                echo "Running the new version..."
                cd ../Job-Marketplace_infra
                ./startup.sh --rebuild --quiet
                cd "${backend_dir}"
        fi



    sleep 600 # wait 10 minutes
done

set +ex
