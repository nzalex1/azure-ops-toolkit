$counter = 1
do {
	echo "Waiting 10 sec for Provisioning status update..."; 	sleep 10
	$status = az resource list --name '${{ parameters.appServiceName }}/${{ parameters.stagingSlot }}' --query '[].provisioningState' -o tsv
	$status = az resource list --name 'func-rt-psd-msf-np-rtapoc/staging' --query '[].provisioningState' -o tsv
	write-host "Provisioning Status:" $status
	if (($counter ++) -ge 20) {
		echo "The max waiting period is exeeded, exiting with error"; exit 1
	}		
} while ($status -ne "Succeeded")