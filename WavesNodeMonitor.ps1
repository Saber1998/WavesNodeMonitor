<#
MIT License

Copyright (c) 2022 Saber1998

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Version 1.01

Version History 

02JUN2022 - Version 1.0 Initial Release
23DEC2022 - Update to store user variables into a JSON file.
            Also store Telegram token encrypted instead of in plain text.


# Donation
If you like my work and feel its worthwhile buy me a beer. :)

Waves
3PFWASEmM4h4ZubsR5GKyMAasyhYzS1uPZH

Bitcoin
bc1qu78v2gt6rglfdtyssyykhuhd7p6fm40u8tzpc5

Litecoin
ltc1qjjj5kz3p3nywgn6us2akj4qpa4cf2n09wfvc8q

#>
$Global:ProgressPreference = 'SilentlyContinue'
# Script Configuration Data. Check if config file exists, if not prompt user for details and create config file.
$ConfigFilePath = "$env:USERPROFILE\WavesNodeMonitor\Config\WavesNodeMonitor.json"
$Checkfile = Test-Path -Path $ConfigFilePath
if ($Checkfile -eq $false) {
    New-Item -Path $env:USERPROFILE\WavesNodeMonitor\Config -ItemType Directory | Out-Null
    $NodeIP = Read-Host -Prompt "IP Address of Node to be monitored"
    $NodePort = Read-Host -Prompt "Port to monitor (Default 6869)"
    $NodeWalletAddress = Read-Host -Prompt "Enter Node Wallet Address to be monitored"
    $TokenInput = Read-Host -Prompt "Telegram token"
    $SavedToken = ConvertTo-SecureString $TokenInput -AsPlainText -Force 
    $ChatID = Read-Host -Prompt "Telegram Chat ID"
    $MonitorDetails = [PSCustomObject]@{
        NodeIP            = $NodeIP
        NodePort          = $NodePort
        NodeWalletAddress = $NodeWalletAddress
        TokenInput        = $TokenInput
        SavedToken        = $SavedToken
        ChatID            = $ChatID
    }
    $MonitorDetails | Select-Object NodeIP, NodePort, NodeWalletAddress, ChatID, @{Name = "SavedToken"; Expression = { $_.SavedToken | ConvertFrom-SecureString } } | ConvertTo-Json | Out-File $ConfigFilePath
    $ImportConfig = Get-Content -Path $ConfigFilePath | ConvertFrom-Json
}
else {
    $ImportConfig = Get-Content -Path $ConfigFilePath | ConvertFrom-Json
    $TelegrambotToken = ConvertTo-SecureString $ImportConfig.SavedToken
    $Telegramtoken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TelegrambotToken))
    $ChatID = $ImportConfig.ChatID
    $NodeIP = $ImportConfig.NodeIP
    $NodePort = $ImportConfig.NodePort
    $NodeWalletAddress = $ImportConfig.NodeWalletAddress
}
# Telegram Function, used to notify you if something needs manual intervention with the node being monitored.
Function Send-Telegram {
    Param([Parameter(Mandatory = $true)][String]$Message)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    foreach ($ID in $ChatID) {
        Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$($Telegramtoken)/sendMessage?chat_id=$($ID)&text=$($Message)" -ContentType "application/json;charset=utf-8"
    }
}
# Number of seconds script should sleep before checking the node again. I recommend 5 minutes (300 seconds) as a default.
[int]$SleepTimer = 300

$LoopCount = 0
Do {
    Clear-Host
    $WavesMarket = Invoke-RestMethod -Method Get -Uri "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=waves&order=market_cap_desc&per_page=100&page=1&sparkline=false"
    $USDNMarket = Invoke-RestMethod -Method Get -Uri "https://api.coingecko.com/api/v3/simple/price?ids=neutrino&vs_currencies=USD"
    $WavesUSD = "$" + $WavesMarket.current_price
    $USDN = "$" + $USDNMarket.neutrino.usd
    $Waves = Invoke-RestMethod -Method Get -uri "http://$($NodeIP):$NodePort/addresses/balance/$NodeWalletAddress" -TimeoutSec 20
    $WavesBalance = $Waves.balance
    [decimal]$WavesAmount = $WavesBalance / 100000000
    $5PercentShare = $WavesAmount * 0.05
    $ShareValue = "$" + [math]::Round($5PercentShare * $WavesMarket.current_price, 2)
    $Block = Invoke-RestMethod -Method Get -uri "http://$($NodeIP):$NodePort/blocks/height" -TimeoutSec 20
    $NodeHeight = $Block.height
    $WavesNetworkBlock = Invoke-RestMethod -Method Get -Uri "https://nodes.wavesplatform.com/blocks/height" -TimeoutSec 30
    $NetworkHeight = $WavesNetworkBlock.height
    Write-Host " "
    Write-Host "Node Waves balance: $WavesAmount" -ForegroundColor Green
    $WavesLease = Invoke-RestMethod -Method Get -Uri "http://$($NodeIP):$NodePort/leasing/active/$NodeWalletAddress" -TimeoutSec 30
    $NumberOfLeases = $WavesLease.count
    $LeaseAmounts = $WavesLease.amount
    $LeaseTotals = foreach ($Lease in $LeaseAmounts) { $Lease / 100000000 }
    $LeaseDisplay = $LeaseTotals | Sort-Object -Descending
    $WavesSum = 0
    $LeaseAmounts | ForEach-Object { $WavesSum += $_ }
    [decimal]$NodeWeight = $WavesSum + $WavesBalance
    [decimal]$EffectiveWeight = $NodeWeight / 100000000
    $TcpClient = New-Object System.Net.Sockets.TcpClient
    $TcpClient.Connect($NodeIP, $NodePort)
    if ($TcpClient.Connected) {
        Write-Host " "
        Write-Host "Node TCP Port Responsive"-ForegroundColor Green
        $TcpClient.Close()
    }
    else {
        Write-Host " "
        Write-Host "Port $NodePort is not responsive" -ForegroundColor Red
        Send-Telegram -Message "Node TCP Port did not respond, check firewall and or if Node software is running" | Out-Null
        
    }
    Write-Host " "
    Write-Host "Node has $NumberOfLeases leases" -ForegroundColor Cyan
    Write-Host "Waves Leased to Node per lease:" -ForegroundColor Green
    Write-Host "$LeaseDisplay" -ForegroundColor Magenta
    Write-host " "
    Write-Host "Effective Node Weight: $EffectiveWeight" -ForegroundColor Green
    if ($NodeHeight -match $NetworkHeight) {
        Write-Host " "
        Write-Host "Waves Node Block Height is $NodeHeight" -ForegroundColor Yellow
        Write-Host "Waves Network Block Height is $NetworkHeight" -ForegroundColor Yellow
        Write-Host "Node is in Sync with Waves Network..." -ForegroundColor Cyan
    }
    elseif ($NodeHeight -ge $NetworkHeight) {
        Write-Host "Node is ahead of waves network." -ForegroundColor Magenta
        Write-Host "Node Height is $NodeHeight" -ForegroundColor Cyan
        Write-Host "Network Height is $NetworkHeight" -ForegroundColor Cyan
    }
        
    elseif ($NetworkHeight -ge $NodeHeight + 10) {
        $BlockDifference = $NetworkHeight - $NodeHeight
        Write-Host "Node is behind by $BlockDifference blocks" -ForegroundColor Red 
        Write-Host "Node is out of sync by more than 10 blocks" -ForegroundColor Red
        Write-Host "Notifying Node owner!" -ForegroundColor Red
        Send-Telegram -Message "Node is out of sync with Network, Node Height: $NodeHeight Network Height: $NetworkHeight" | Out-Null

    }    
    $NodeVersion = Invoke-RestMethod -Method Get -Uri "http://$($NodeIP):$NodePort/node/version" -TimeoutSec 10
    $NodeVersionDisplayed = $NodeVersion.version
    $NetworkVersion = Invoke-RestMethod -Method Get -Uri "https://nodes.wavesplatform.com/node/version" -TimeoutSec 10
    $NetworkVersionDisplayed = $NetworkVersion.version
    if ($NodeVersionDisplayed -match $NetworkVersionDisplayed) {
        Write-Host " "
        Write-Host "Node Version is $NodeVersionDisplayed" -ForegroundColor Yellow
        Write-Host "Network Version is $NetworkVersionDisplayed" -ForegroundColor Yellow
        Write-Host "Node is running most up to date version of Waves" -ForegroundColor Cyan
    }
    elseif ($NetworkVersionDisplayed -le $NodeVersionDisplayed) {
        Write-host " "
        Write-Host "Node Version is $NodeVersionDisplayed" -ForegroundColor Green
        Write-Host "Metwork version is $NetworkVersionDisplayed" -ForegroundColor Red
        Write-Host "Node version is newer than Network version" -ForegroundColor Yellow
    }
    else {
        Write-Host " "
        Write-Host "Node Version is $NodeVersionDisplayed" -ForegroundColor Red
        Write-Host "Network Version is $NetworkVersionDisplayed" -ForegroundColor Red
        Write-Host "Node needs to be updated...." -ForegroundColor Red
    }
    $NodeStatus = Invoke-WebRequest -Method Get -Uri "http://$($NodeIP):$NodePort/node/status" -TimeoutSec 30
    $StatusCode = $NodeStatus.StatusCode
    if ($StatusCode -eq "200") {
        Write-Host " "
        Write-Host "Node API is up and responsive. Status Code returned $StatusCode" -ForegroundColor Green
    }
    
    else {
        Write-Host "Node Reported a status code other than 200." -ForegroundColor Red
        Write-Host "Notifying Node Owner." -ForegroundColor Red
        Send-Telegram -Message "Node reported a status code other than 200, Http status returned: $StatusCode"

    } 
    $LoopCount++
    $Time = Get-Date -Format G
    Write-Host " "
    Write-Host ("Script Has Checked Node {0} times (Once every $SleepTimer seconds), last checked at $Time" -f $LoopCount) -ForegroundColor Yellow
    Write-Host " "
    Write-Host "Waves and USDN Market price currently"
    Write-Host " "
    Write-Host "Waves USD Price: $WavesUSD" -ForegroundColor Cyan
    Write-Host "Neutrino USDN Price: $USDN" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your share of Waves Balance: $5PercentShare"
    Write-Host "Share value: $ShareValue "
    
    # Variable clean up to ensure script is reporting accurate data.
    $NodeStatus = $null
    $StatusCode = $null
    $Waves = $null
    $Wavesbalance = $null
    $Block = $null
    $NodeHeight = $null
    $NetworkHeight = $null
    $WavesNetworkBlock = $null
    $WavesLease = $null
    [decimal]$WavesAmount = $null
    $LeaseDisplay = $null
    [decimal]$NodeWeight = $null
    [decimal]$EffectiveWeight = $null
    $NodeVersion = $null
    $NetworkVersion = $null
    $NodeVersionDisplayed = $null
    $NetworkVersionDisplayed = $null
    $BlockDifference = $null
    $Time = $null
    $WavesMarket = $null
    $WavesUSD = $null
    $USDNMarket = $null
    $USDN = $null
    $5PercentShare = $null
    $ShareValue = $null
    Start-Sleep -Seconds $SleepTimer
}
While ($true)