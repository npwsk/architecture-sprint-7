#!/bin/bash

echo "Применяем роли и кластерные роли"

kubectl apply -f roles/cluster-configurator.yaml
kubectl apply -f roles/cluster-viewer.yaml
kubectl apply -f roles/developer.yaml
kubectl apply -f roles/auditor.yaml

echo "Проверяем созданные роли"

kubectl get clusterroles | grep -E 'cluster-configurator|cluster-viewer|auditor'

kubectl get roles | grep developer
