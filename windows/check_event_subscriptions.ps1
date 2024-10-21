# Created by Check_MK Agent Bakery.
# This file is managed via WATO, do not edit manually or you
# lose your changes next time when you update the agent.

# Version 0.1 - Manuel Michalski (www.47k.de)
# Last Update: 20.10.2024
# Description: CheckMK Local Check for Windows Event Viewer Subscriptions / Checks if subscriptions are active or inactive

# Execute wecutil command and store output in a variable
$subscriptions = wecutil es

# Initialization
$subscription_status = 0
$detailed_output = ""
$summary = ""
$count = 0

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Clean up subscription name (remove whitespace and line breaks)
    $subscriptionName = $subscription.Trim()

    # Query the status of the subscription and store in a variable
    $status_output = wecutil gr "$subscriptionName"

    # Find the overall status of the subscription, ignoring EventSources
    $overall_status = $status_output | Select-String -Pattern "RunTimeStatus:\s*Active|RunTimeStatus:\s*Inactive" | Select-Object -First 1

    # Check if the overall status is "Inactive" or "Active"
    if ($overall_status -match "RunTimeStatus:\s*Inactive") {
        # Subscription is inactive
        $detailed_output += " ($subscriptionName) is inactive \n"
        $summary += "$subscriptionName, "
        $count++
    } elseif ($overall_status -match "RunTimeStatus:\s*Active") {
        # Subscription is active (ignore)
        continue
    } else {
        # If another status is returned, issue a warning
        $detailed_output += " ($subscriptionName) has an unknown status \n"
        $summary += "$subscriptionName (unknown status), "
        $count++
    }
}

# Remove the last ", " from the summary
if ($summary.Length -gt 2) {
    $summary = $summary.Substring(0, $summary.Length - 2)
}

# Output result for CheckMK
Write-Host "<<<local>>>"
if ($count -gt 0) {
    Write-Host "2 'Windows Subscriptions' - $count subscriptions are inactive: $summary \n $detailed_output"
    exit 2
} else {
    Write-Host "0 'Windows Subscriptions' - All subscriptions are active"
    exit 0
}
