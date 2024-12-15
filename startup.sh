#!/bin/bash
# Example usage:
# ./startup.sh -> puts compose down, and starts compose again
# ./startup.sh --k8s -> runs using k8s, provided that you already have minikube and docker setup locally
# ./startup.sh --rebuild -> additionally rebuilds all images before starting compose again


# Initialize flags
k8s=false
k8s_full=false
rebuild=false
soft_rebuild=false
profile="zpi"
pkl=false
run_linter=false
quiet=false

# Set env variables
INFRA_FOLDER='.'
BACKEND_FOLDER='../Job-Marketplace_backend'
FRONTEND_FOLDER='../Job-Marketplace_frontend'
set -ex

# Parse command-line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --k8s) k8s=true ;;
        --rebuild) rebuild=true ;;
		--k8s-full) k8s_full=true ;;
		--k8s_full) k8s_full=true ;;
		--lint) run_linter=true ;;
		--pkl) pkl=true ;;
		--quiet) quiet=true ;;
		--soft-rebuild) soft_rebuild=true  ;;
        *) echo "Unknown option: $1" ;;
    esac
    shift
done

# Cleanup
if ! $soft_rebuild; then
	echo "--- Docker compose down ---"
	docker compose -f ${INFRA_FOLDER}/compose.yaml down --remove-orphans
	docker compose rm -f
	# docker rm -fv job_market_db_local
fi 


echo $soft_rebuild "succesus"

run_linter() {
	kube-linter lint $(find -path '*database-slaves/*.yaml')
}

load_images() {

	# load images if not present
	# if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_user_service' ); then
		minikube image load --overwrite job_market_user_service:latest -p="${profile}"
	# fi

	# if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_database' ); then
		minikube image load --overwrite job_market_database:latest -p="${profile}"


		minikube image load  --overwrite job_market_database_master:latest -p="${profile}"
	# fi

	# if ! ( minikube image ls -minikube startp="${profile}" | grep -q 'job_market_db_fill' ); then
		minikube image load --overwrite job_market_db_fill:latest -p="${profile}"
	# fi

	# if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_job_service' ); then
		minikube image load --overwrite job_market_job_service:latest -p="${profile}"
	# fi

	# if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_chat' ); then
	# minikube image rm job_market_chat:latest -p="${profile}"
	minikube image load --overwrite job_market_chat:latest -p="${profile}"


	minikube image load --overwrite job_market_front:latest -p="${profile}"



	minikube image load --overwrite job_market_gateway:latest -p="${profile}"
	# fi

	# if ! ( kubectl config current-context | grep -qv "${profile}" ); then

	# fi
}

if $pkl; then
	# rebuild Pkl config files
	pkl eval -p input=${INFRA_FOLDER}/k8s/volumes/pv_config.pkl -o ${INFRA_FOLDER}/k8s/volumes/pv_generated.yaml || echo "--- [WARNING] pkl generation has failed ---"
fi

rebuild() {
	if $rebuild || $soft_rebuild; then

		# if $k8s || $k8s_full;then
		# 	eval $(minikube -p="${profile}" docker-env --shell=bash)
		# fi
		build_dir=$(pwd)
		cd ${BACKEND_FOLDER}/services
		echo $build_dir
		echo $(pwd)
		docker build -f db/Dockerfile . -t docker.local:5000/job_market_database -t job_market_database
		docker build -f db/Dockerfile_master . -t docker.local:5000/job_market_database_master -t job_market_database_master
		docker build -f user-service/Dockerfile . -t job_market_user_service -t docker.local:5000/job_market_user_service
		docker build -f analytics/Dockerfile . -t job_market_analytics -t docker.local:5000/job_market_analytics
		docker build -f api-gateway/Dockerfile . -t job_market_gateway -t docker.local:5000/job_market_gateway
		docker build -f notification-service/Dockerfile . -t job_market_notification -t docker.local:5000/job_market_notification
		docker build -f db_mockup/Dockerfile . -t docker.local:5000/job_market_db_fill -t job_market_db_fill
		docker build -f chat_go/Dockerfile . -t docker.local:5000/job_market_chat -t job_market_chat
		docker build -f job-service/Dockerfile . -t docker.local:5000/job_market_job_service -t job_market_job_service
		cd $build_dir
		cd ${FRONTEND_FOLDER}
		docker build . -t job_market_front
		cd $build_dir
	fi
}




if $k8s || $k8s_full; then


    if $(minikube status | grep -q 'apiserver: Stopped'); then
		minikube start -p="${profile}" --driver=docker --cpus 6 --memory 10000 --static-ip 192.168.10.10
	fi
	if $k8s_full; then
		kubectl delete -k ${INFRA_FOLDER}/k8s/clusters/"${profile}"/ || echo "--- [WARNING] Couldn't delete everything ---"
		# workaorund, cause action just initiates deletion process
		sleep 60s
	fi


	rebuild
	if $rebuild; then
		load_images
	fi
	kubectl config set-cluster "${profile}"
	kubectl config set-context --current --namespace dev
	# kubectl delete --force -k ${INFRA_FOLDER}/k8s/clusters/"${profile}"/ || echo "--- [WARNING] Couldn't delete everything ---"
	kubectl apply -k ${INFRA_FOLDER}/k8s/clusters/"${profile}"/

		# minikube -p=${profile} tunnel --cleanup=true & echo 'Added minikube tunnel'
	minikube -p=${profile} addons enable ingress
	minikube -p=${profile} addons enable metrics-server
	minikube -p=${profile} addons enable volumesnapshots
	minikube -p=${profile} addons enable csi-hostpath-driver

	# restart deplyoments to allow for configmaps update
	kubectl rollout restart deployment
	echo "--- TO CONNECT RUN: 'minikube tunnel -p=zpi' ---"
	minikube dashboard -p="${profile}"

	

else
	if $soft_rebuild; then
		docker rm -f job_market_user_service
		docker rm -f job_market_job_service
		docker rm -f job_market_notification
		docker rm -f job_market_chat

		docker compose up -d job_market_user_service
		docker compose up -d job_market_job_service
		docker compose up -d job_market_notification
		docker compose up -d job_market_chat
	elif $rebuild; then
		rebuild
		./scripts/generate_jwt.sh
	fi
	
	
	docker compose -f ${INFRA_FOLDER}/compose.yaml up -d --force-recreate
	if ! $quiet; then
			watch -n 1 docker compose -f ${INFRA_FOLDER}/compose.yaml ps
	fi

fi

set +ex
