#!/usr/bin/env bash

status=$(netbird status --json)

echo -e "\033[36mNetBird Peer Connection Types:\033[0m"
echo "================================"

current_type=""

while IFS= read -r line; do
    conn_type=$(echo "$line" | jq -r '.connectionType')
    fqdn=$(echo "$line" | jq -r '.fqdn // "Unknown"')

    [[ "$conn_type" == "-" || -z "$conn_type" ]] && continue

    case "$conn_type" in
        P2P)     type_label="Direct (P2P)";      color="\033[32m" ;;
        Relayed) type_label="Relayed (Gateway)";  color="\033[33m" ;;
        *)       type_label="$conn_type";         color="\033[0m"  ;;
    esac

    if [[ "$conn_type" != "$current_type" ]]; then
        [[ -n "$current_type" ]] && echo ""
        echo -e "\033[36m--- $type_label ---\033[0m"
        current_type="$conn_type"
    fi

    echo -e "  ${color}${fqdn}\033[0m"
done < <(echo "$status" | jq -c '.peers.details[] | {connectionType, fqdn}' | sort -t'"' -k4)

connected=$(echo "$status" | jq '[.peers.details[] | select(.connectionType == "P2P")] | length')
relayed=$(echo "$status" | jq '[.peers.details[] | select(.connectionType == "Relayed")] | length')
total=$((connected + relayed))

echo -e "\n\033[36mConnected: $total peers ($connected Direct | $relayed Relayed)\033[0m"
