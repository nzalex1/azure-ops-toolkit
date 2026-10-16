param(
    [parameter(Mandatory=$true)]
	[String] $Subscription
)


select-AzSubscription -subscriptionName $Subscription

$newTags = @{ScheduleIgnore="1"}

get-AzVM | ForEach-Object {
    write-host "Processing the VM:" $_.name -ForegroundColor Yellow
    # $newTags = $_.tags
    # $newTags.remove("ScheduleIgnore")
    $_ | get-azresource | update-AzTag -tag $newTags -Operation Delete
}

