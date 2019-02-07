#!/bin/bash
# set -x

# the project id
project="zeelos"

# Google GCP region/zone
region="europe-west3"
zone="a"

# used as prefix for resources
network="$project-$region-$zone"

# Docker Swarm spec.
managers=3
workers=6

first_manager_ip=$(gcloud compute instances describe \
    --zone $region-$zone \
    --format 'value(networkInterfaces[0].networkIP)' \
$network-swarm-manager-1)

echo "initializing swarm cluster on first manager '$network-swarm-manager-1' ($first_manager_ip).."
gcloud compute ssh "$network-swarm-manager-1" --internal-ip \
--command "sudo docker swarm init --advertise-addr $first_manager_ip"

echo "retrieving manager token for manager node '$network-swarm-manager-1'.."
manager_token=$(gcloud compute ssh $network-swarm-manager-1 --internal-ip \
--command "sudo docker swarm join-token manager | grep token | awk '{ print \$5 }'")

echo "manager token retrieved, attempting to join manager followers.."
for id in $(seq 2 $managers); do
    echo "joining manager node '$network-swarm-manager-$id..'"
    gcloud compute ssh "$network-swarm-manager-$id" --internal-ip \
    --command "sudo docker swarm join --token $manager_token $first_manager_ip:2377"
done

echo "retrieving worker token from manager node '$network-swarm-manager-1'.."
worker_token=$(gcloud compute ssh $network-swarm-manager-1 --internal-ip \
--command "sudo docker swarm join-token worker | grep token | awk '{ print \$5 }'")

echo "worker token retrieved, attempting to join worker nodes.."
for id in $(seq 1 $workers); do
    echo "joining worker node '$network-swarm-worker-$id..'"
    gcloud compute ssh "$network-swarm-worker-$id" --internal-ip \
    --command "sudo docker swarm join --token $worker_token $first_manager_ip:2377"
done

echo
echo "Have a lot of fun..."