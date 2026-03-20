# Parse NetBird JSON output
$status = netbird status --json | ConvertFrom-Json

Write-Host "NetBird Peer Connection Types:" -ForegroundColor Cyan
Write-Host "================================"

# Filter out connecting peers and sort by connection type (P2P first, then Relayed)
$sortedPeers = $status.peers.details | Where-Object { $_.connectionType -ne "-" } | Sort-Object @{
    Expression = {
        switch ($_.connectionType) {
            "P2P"     { 1 }
            "Relayed" { 2 }
            default   { 3 }
        }
    }
}

$currentType = ""
foreach ($peer in $sortedPeers) {
    $name = if ($peer.fqdn) { $peer.fqdn } else { "Unknown" }
    
    # Determine connection type based on connectionType field
    switch ($peer.connectionType) {
        "P2P"     { $type = "Direct (P2P)"; $color = "Green" }
        "Relayed" { $type = "Relayed (Gateway)"; $color = "Yellow" }
        default   { $type = $peer.connectionType; $color = "White" }
    }
    
    # Print section header when connection type changes
    if ($peer.connectionType -ne $currentType) {
        if ($currentType -ne "") { Write-Host "" }
        Write-Host "--- $type ---" -ForegroundColor Cyan
        $currentType = $peer.connectionType
    }
    
    Write-Host "  $name" -ForegroundColor $color
}

# Summary
$connected = ($status.peers.details | Where-Object { $_.connectionType -eq "P2P" }).Count
$relayed = ($status.peers.details | Where-Object { $_.connectionType -eq "Relayed" }).Count
$total = $connected + $relayed
Write-Host "`nConnected: $total peers ($connected Direct | $relayed Relayed)" -ForegroundColor Cyan
