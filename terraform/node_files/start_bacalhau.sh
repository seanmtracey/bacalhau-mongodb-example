#!/bin/bash
# shellcheck disable=SC1091,SC2312,SC2155
set -euo pipefail
IFS=$'\n\t'

# we start with none as the default ("none" prevents the node connecting to our default bootstrap list)
export CONNECT_PEER="none"

EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

echo "${EXTERNAL_IP}"

# if the file /etc/bacalhau-bootstrap exists, use it to populate the CONNECT_PEER variable
if [[ -f /etc/bacalhau-bootstrap ]]; then
  # shellcheck disable=SC1090
  source /etc/bacalhau-bootstrap
  CONNECT_PEER="${BACALHAU_NODE_LIBP2P_PEERCONNECT}"
fi

# If /etc/bacalhau-node-info exists, then load the variables from it
if [[ -f /etc/bacalhau-node-info ]]; then
  # shellcheck disable=SC1090
  . /etc/bacalhau-node-info
fi

labels="ip=${EXTERNAL_IP}"

# If REGION is set, then we can assume all labels are set, and we should add it to the labels
if [[ -n "${REGION}" ]]; then
  labels="${labels},region=${REGION},zone=${ZONE},appname=${APPNAME}"
fi

bacalhau serve \
  --node-type requester,compute \
  --job-selection-data-locality anywhere \
  --swarm-port 1235 \
  --api-port 1234 \
  --peer "${CONNECT_PEER}" \
  --private-internal-ipfs=true \
  --allow-listed-local-paths '/db' \
  --allow-listed-local-paths '/var/log/logs_to_process/**' \
  --job-selection-accept-networked \
  --labels "${labels}" \
  --network libp2p 