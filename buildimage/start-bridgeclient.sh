#!/bin/bash
set -e -x

export CLIENT=$HOSTNAME
export PATTOKENID=$HOSTNAME
export PAT_TOKEN=$(cat "/etc/secret/pat" | python -c \
    'import json,sys,os;print(json.load(sys.stdin)[os.getenv("HOSTNAME")])')


/opt/tableau/tableau_bridge/bin/TabBridgeClientWorker -e \
    --client="${CLIENT}" \
    --site="${SITE}" \
    --serverPod="${SERVERPOD}" \
    --userEmail="${USEREMAIL}" \
    --patTokenId="${PATTOKENID}"
