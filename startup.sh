#!/bin/bash
# Example usage:
# ./startup.sh -> puts compose down, and starts compose again
# ./startup.sh --k8s -> runs using k8s, provided that you already have minikube and docker setup locally
# ./startup.sh --rebuild -> additionally rebuilds all images before starting compose again


# Initialize flags
k8s=false
k8s_full=false
rebuild=false
profile="zpi"
pkl=false
run_linter=false
quiet=false

# Set env variables
INFRA_FOLDER='.'
BACKEND_FOLDER='../Job-Marketplace_backend'
set -ex

# Cleanup
docker compose -f ${INFRA_FOLDER}/compose.yaml down --remove-orphans
docker compose rm -f
docker rm -fv job_market_db_local

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
        *) echo "Unknown option: $1" ;;
    esac
    shift
done


run_linter() {
	kube-linter lint $(find -path '*database-slaves/*.yaml')
}

load_images() {
	# load images if not present
	if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_backend' ); then
		minikube image load job_market_backend:latest -p="${profile}"
	fi

	if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_database' ); then
		minikube image load job_market_database:latest -p="${profile}"
	fi

	if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_db_fill' ); then
		minikube image load job_market_db_fill:latest -p="${profile}"
	fi

	# if ! ( minikube image ls -p="${profile}" | grep -q 'job_market_chat' ); then
	# minikube image rm job_market_chat:latest -p="${profile}"
	minikube image load job_market_chat:latest -p="${profile}"
	# fi

	if ! ( kubectl config current-context | grep -qv "${profile}" ); then
		kubectl config set-cluster "${profile}"
		kubectl config set-context --current --namespace dev
	fi
}

if $pkl; then
	# rebuild Pkl config files
	pkl eval -p input=${INFRA_FOLDER}/k8s/volumes/pv_config.pkl -o ${INFRA_FOLDER}/k8s/volumes/pv_generated.yaml || echo "--- [WARNING] pkl generation has failed ---"
fi


if $rebuild; then
	build_dir=$(pwd)
	cd ${BACKEND_FOLDER}/services
	echo $build_dir
	echo $(pwd)
    docker build -f db/Dockerfile . -t docker.local:5000/job_market_database -t job_market_database
	docker build -f user-service/Dockerfile . -t job_market_user_service
	docker build -f api-gateway/Dockerfile . -t job_market_gateway
	docker build -f notification-service/Dockerfile . -t job_market_notification
	docker build -f db_mockup/Dockerfile . -t docker.local:5000/job_market_db_fill -t job_market_db_fill
	docker build -f chat_go/Dockerfile . -t docker.local:5000/job_market_chat -t job_market_chat
	cd $build_dir
fi


if $k8s || $k8s_full; then

	if $k8s_full; then
		# echo "what to do ?..."
		kubectl delete -k ${INFRA_FOLDER}/k8s/clusters/"${profile}"/ || echo "--- [WARNING] Couldn't delete everything ---"
	fi
	minikube start -p="${profile}" --driver=docker --cpus 6 --memory 10000 --static-ip 192.168.10.10
	sleep 10s



	load_images

	kubectl apply -k ${INFRA_FOLDER}/k8s/clusters/"${profile}"/

		# minikube -p=${profile} tunnel --cleanup=true & echo 'Added minikube tunnel'
	minikube -p=${profile} addons enable ingress
	minikube -p=${profile} addons enable metrics-server
	minikube -p=${profile} addons enable volumesnapshots
	minikube -p=${profile} addons enable csi-hostpath-driver

	# restart deplyoments to allow for configmaps update
	kubectl rollout restart deployment

	minikube dashboard -p="${profile}"

else

	./scripts/generate_jwt.sh
	docker compose -f ${INFRA_FOLDER}/compose.yaml up -d --force-recreate
	if ! $quiet; then
			watch -n 1 docker compose -f ${INFRA_FOLDER}/compose.yaml ps
	fi

fi

set +ex
