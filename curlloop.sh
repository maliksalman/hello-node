while true; do sleep 0.5; curl -s $1 | jq . -c; done
