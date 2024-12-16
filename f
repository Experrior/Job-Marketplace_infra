#!/bin/bash
kubectl delete -n dev statefulset master-statefulset;
kubectl delete -n dev statefulset slave-statefulset;
kubectl delete -n dev statefulset postgres-replica;
kubectl apply -k k8s/clusters/zpi/
