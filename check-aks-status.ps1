# ========================================
# AKS Deployment Status Check Script
# ========================================

Write-Host "Starting AKS Deployment Status Check..." -ForegroundColor Green
Write-Host ""

$resourceGroup = "rg-wizapp-compute-nonprod-eastus2-001"
$clusterName = "aks-wizapp-nonprod-eastus2-001"
$namespace = "wizapp"

function Invoke-AksCommand {
    param($command)
    az aks command invoke --resource-group $resourceGroup --name $clusterName --command $command --output table
}

function Invoke-AksCommandTsv {
    param($command)
    az aks command invoke --resource-group $resourceGroup --name $clusterName --command $command --output tsv
}

# ========================================
# 1. OVERALL CLUSTER STATUS
# ========================================
Write-Host "OVERALL CLUSTER STATUS" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow
try {
    Invoke-AksCommand "kubectl get all -n $namespace"
} catch {
    Write-Host "Failed to get cluster status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 2. POD STATUS DETAILS
# ========================================
Write-Host "POD STATUS DETAILS" -ForegroundColor Yellow
Write-Host "=====================" -ForegroundColor Yellow
try {
    Write-Host "All pods in namespace:"
    Invoke-AksCommand "kubectl get pods -n $namespace"
    Write-Host ""
    
    Write-Host "Pods with app=wizapp label:"
    Invoke-AksCommand "kubectl get pods -n $namespace -l app=wizapp -o wide"
} catch {
    Write-Host "Failed to get pod status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 3. DEPLOYMENT STATUS
# ========================================
Write-Host "DEPLOYMENT STATUS" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor Yellow
try {
    Invoke-AksCommand "kubectl get deployment wizapp-deployment -n $namespace"
    Write-Host ""
    Write-Host "Deployment description:"
    Invoke-AksCommand "kubectl describe deployment wizapp-deployment -n $namespace"
} catch {
    Write-Host "Failed to get deployment status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 4. SERVICE & LOADBALANCER STATUS
# ========================================
Write-Host "SERVICE & LOADBALANCER STATUS" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow
try {
    Write-Host "Service details:"
    Invoke-AksCommand "kubectl get svc wizapp-service -n $namespace -o wide"
    Write-Host ""
    
    Write-Host "Checking for LoadBalancer IP..."
    $lbIP = Invoke-AksCommandTsv "kubectl get svc wizapp-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
    if ($lbIP -and $lbIP -ne "") {
        Write-Host "LoadBalancer IP: $lbIP" -ForegroundColor Green
    } else {
        Write-Host "LoadBalancer IP not yet assigned (still provisioning)" -ForegroundColor Yellow
        $clusterIP = Invoke-AksCommandTsv "kubectl get svc wizapp-service -n $namespace -o jsonpath='{.spec.clusterIP}'"
        Write-Host "Cluster IP: $clusterIP" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to get service status: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 5. CONFIGMAP STATUS
# ========================================
Write-Host "CONFIGMAP STATUS" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor Yellow
try {
    Write-Host "ConfigMap details:"
    Invoke-AksCommand "kubectl get configmap wizapp-config -n $namespace"
    Write-Host ""
    Write-Host "ConfigMap contents (MongoDB URI will be masked):"
    $configOutput = Invoke-AksCommandTsv "kubectl get configmap wizapp-config -n $namespace -o yaml"
    $configOutput -replace 'mongodb://[^@]*@', 'mongodb://***:***@'
} catch {
    Write-Host "Failed to get ConfigMap: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 6. POD LOGS (if pods exist)
# ========================================
Write-Host "POD LOGS (Last 10 lines)" -ForegroundColor Yellow
Write-Host "============================" -ForegroundColor Yellow
try {
    $podExists = Invoke-AksCommandTsv "kubectl get pods -n $namespace -l app=wizapp --no-headers | wc -l"
    if ($podExists -and $podExists -gt 0) {
        Write-Host "Recent pod logs:"
        Invoke-AksCommand "kubectl logs -n $namespace -l app=wizapp --tail=10"
    } else {
        Write-Host "No pods found with app=wizapp label" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to get pod logs: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 7. WIZEXERCISE.TXT VALIDATION  
# ========================================
Write-Host "WIZEXERCISE.TXT VALIDATION" -ForegroundColor Yellow
Write-Host "==============================" -ForegroundColor Yellow
try {
    # Get the first pod name directly using jsonpath
    $podNameCommand = "kubectl get pods -n $namespace -l app=wizapp -o jsonpath='{.items[0].metadata.name}'"
    $rawOutput = az aks command invoke --resource-group $resourceGroup --name $clusterName --command $podNameCommand --output json 2>$null | ConvertFrom-Json
    
    if ($rawOutput.exitCode -eq 0 -and $rawOutput.logs) {
        $podName = $rawOutput.logs.Trim()
        if ($podName -and $podName -ne "") {
            Write-Host "Found pod: $podName" -ForegroundColor Green
            Write-Host "File contents:"
            Invoke-AksCommand "kubectl exec -n $namespace $podName -- cat /app/wizexercise.txt"
        } else {
            Write-Host "No pods found with app=wizapp label" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No running pods found to check wizexercise.txt" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to validate wizexercise.txt: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 8. NAMESPACE EVENTS
# ========================================
Write-Host "RECENT NAMESPACE EVENTS" -ForegroundColor Yellow
Write-Host "==========================" -ForegroundColor Yellow
try {
    Write-Host "Recent events in wizapp namespace:"
    Invoke-AksCommand "kubectl get events -n $namespace --sort-by='.lastTimestamp' | tail -10"
} catch {
    Write-Host "Failed to get events: $($_.Exception.Message)" -ForegroundColor Red
}
Write-Host ""

# ========================================
# 9. HEALTH CHECK SUMMARY
# ========================================
Write-Host "HEALTH CHECK SUMMARY" -ForegroundColor Yellow
Write-Host "=======================" -ForegroundColor Yellow

$healthChecks = @()

# Check namespace exists
try {
    $nsExists = Invoke-AksCommandTsv "kubectl get namespace $namespace --no-headers | wc -l"
    if ($nsExists -gt 0) {
        $healthChecks += "Namespace exists"
    } else {
        $healthChecks += "Namespace missing"
    }
} catch {
    $healthChecks += "Cannot check namespace"
}

# Check deployment
try {
    $deployReady = Invoke-AksCommandTsv "kubectl get deployment wizapp-deployment -n $namespace -o jsonpath='{.status.readyReplicas}'"
    $deployDesired = Invoke-AksCommandTsv "kubectl get deployment wizapp-deployment -n $namespace -o jsonpath='{.spec.replicas}'"
    if ($deployReady -eq $deployDesired -and $deployReady -gt 0) {
        $healthChecks += "Deployment ready ($deployReady/$deployDesired)"
    } else {
        $healthChecks += "Deployment not ready ($deployReady/$deployDesired)"
    }
} catch {
    $healthChecks += "Cannot check deployment"
}

# Check service
try {
    $svcExists = Invoke-AksCommandTsv "kubectl get svc wizapp-service -n $namespace --no-headers | wc -l"
    if ($svcExists -gt 0) {
        $healthChecks += "Service exists"
    } else {
        $healthChecks += "Service missing"
    }
} catch {
    $healthChecks += "Cannot check service"
}

# Check LoadBalancer IP
try {
    $lbIP = Invoke-AksCommandTsv "kubectl get svc wizapp-service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
    if ($lbIP -and $lbIP -ne "") {
        $healthChecks += "LoadBalancer IP assigned: $lbIP"
    } else {
        $healthChecks += "LoadBalancer IP pending"
    }
} catch {
    $healthChecks += "Cannot check LoadBalancer"
}

foreach ($check in $healthChecks) {
    Write-Host $check
}

Write-Host ""
Write-Host "Status check complete!" -ForegroundColor Green
Write-Host "If you see issues above, the deployment may still be in progress or there may be configuration problems." -ForegroundColor Green