#!/bin/bash
set -e

kind create cluster --config kind-config.yaml
sed -i '' 's/https:\/\/:/https:\/\/localhost:/g' ~/.kube/config

kind load docker-image localhost/security-profiles-operator:latest

kubectl apply -k github.com/chrisns/syslog-auditd

kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml
kubectl --namespace cert-manager wait --timeout=360s --for condition=ready pod -l app.kubernetes.io/instance=cert-manager

cd security-profiles-operator
git apply <hack/deploy-localhost.patch
kubectl apply -f deploy/operator.yaml
cd ..

# kubectl scale --namespace security-profiles-operator deployment security-profiles-operator --replicas=1
# kubectl scale --namespace security-profiles-operator deployment security-profiles-webhook --replicas=1
sleep 60

kubectl --namespace security-profiles-operator wait --timeout=360s --for condition=ready pods -l name=spod
# kubectl apply -f spod.yaml
# kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableBpfRecorder":true}}'
kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"hostProcVolumePath":"/hostproc"}}'
kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableLogEnricher":true}}'
# kubectl --namespace security-profiles-operator patch spod spod --type=merge -p '{"spec":{"enableBpfRecorder":true}}'
sleep 2
kubectl --namespace security-profiles-operator wait --timeout=120s --for condition=ready pods -l name=spod


# kubectl --namespace security-profiles-operator wait --for condition=ready --timeout=-1s ds spod
kubectl apply -f https://raw.githubusercontent.com/appvia/security-profiles-operator-demo/main/demo-recorder.yaml

sleep 2

kubectl run my-pod --image=nginx --labels app=demo
kubectl wait --for condition=ready --timeout=60s pod my-pod
kubectl delete pod my-pod
sleep 5

kubectl wait --for condition=ready --timeout=60s sp demo-recorder-my-pod

kubectl get events -A > events.log
kubectl get sp -A -o yaml > sps.yaml
kubectl logs -n security-profiles-operator  ds/spod -c log-enricher > log-enricher.log
# kubectl logs -n security-profiles-operator  ds/spod -c bpf-recorder > bpf-recorder.log