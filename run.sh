#!/bin/bash
brew install kind helm kubectl

kind create cluster --config kind-podman-config.yaml
kubectl apply -f syslog.yaml
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/security-profiles-operator/main/deploy/operator.yaml
kubectl scale --namespace security-profiles-operator deployment security-profiles-operator --replicas=1
kubectl scale --namespace security-profiles-operator deployment security-profiles-webhook --replicas=1
kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s ds spod
kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableLogEnricher":true,"enableBpfRecorder":true}}'
kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s ds spod
kubectl apply -f https://raw.githubusercontent.com/appvia/security-profiles-operator-demo/main/demo-recorder.yaml
