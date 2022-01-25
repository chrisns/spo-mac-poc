#!/bin/bash
# brew install kind helm kubectl

kind create cluster --config kind-config.yaml
sed -i '' 's/https:\/\/:/https:\/\/localhost:/g' ~/.kube/config

kind load docker-image localhost/security-profiles-operator:latest

kubectl apply -f syslog.yaml

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml
kubectl --namespace cert-manager wait --for condition=ready pod -l app.kubernetes.io/instance=cert-manager

cd security-profiles-operator
git apply <hack/deploy-localhost.patch
kubectl apply -f deploy/operator.yaml
cd ..

# kubectl scale --namespace security-profiles-operator deployment security-profiles-operator --replicas=1
# kubectl scale --namespace security-profiles-operator deployment security-profiles-webhook --replicas=1
sleep 0.5
kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s ds spod
kubectl apply -f spod.yaml
kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s spod spod
# kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableLogEnricher":true,"enableBpfRecorder":true}}'

# kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s ds spod
kubectl apply -f https://raw.githubusercontent.com/appvia/security-profiles-operator-demo/main/demo-recorder.yaml

kubectl run my-pod --image=nginx --labels app=demo

kubectl wait --for condition=ready --timeout=-1s pod my-pod

kubectl delete pod my-pod
sleep 5

kubectl wait --for condition=ready sp demo-recorder-my-pod

kubectl get events -A > events.log
kubectl get sp -A -o yaml > sps.yaml
kubectl logs -n security-profiles-operator  ds/spod -c log-enricher > log-enricher.log
# kubectl logs -n security-profiles-operator  ds/spod -c bpf-recorder > bpf-recorder.log