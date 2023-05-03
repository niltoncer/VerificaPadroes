function CheckPattern($zipPath,$logView){

    #Verificando e pagando possível pasta temporária remanescente
    If(Test-Path "$($env:TEMP)\tempFolder"){
        Remove-Item -Path "$($env:TEMP)\tempFolder" -Recurse -Force
    }

    #Criando nova pasta temporária
    New-Item -Path "$($env:TEMP)\tempFolder" -ItemType Directory

    #Extraindo arquivo zip na pasta temporária criada
    Expand-Archive -Path $zipPath -DestinationPath "$($env:TEMP)\tempFolder"

    Write-Host ""
    Write-Host "INICIANDO PROCESSO DE VERIFICACAO DE PADROES" -ForegroundColor Yellow
    Write-Host ""

    # Caminhos para arquivos na pasta temporária
    [string]$solutionPath = "$($env:TEMP)\tempFolder\solution.xml"
    [string]$customizationsPath = "$($env:TEMP)\tempFolder\customizations.xml"

    # Armazenando conteúdo dos arquivos
    [xml]$solution = Get-Content $solutionPath
    [xml]$customizations = Get-Content $customizationsPath

    # Armazenando caminho para propriedades-chave dos arquivos XML
    $canvasApps = $customizations.ImportExportXml.CanvasApps
    $workflows = $customizations.ImportExportXml.Workflows
    $solutionName = $solution.ImportExportXml.SolutionManifest.UniqueName

    #Declarando listas que armazenaram valores chave
    $appNames = @()
    $flowNames = @()
    $listNames = @()
    $connectionReferencesList = @()

    #Obtendo os valores de 'DisplayName' e 'ConnectionReferences' das aplicações contidas no arquivo customization.xml
    foreach ($app in $canvasApps) {
        $appNames = $app.CanvasApp.DisplayName
        $connectionReferences = $app.CanvasApp.ConnectionReferences
        foreach ($connection in $connectionReferences) {
            $connectionReferencesList += $connection | ConvertTo-Json | ConvertFrom-Json
        }
    }

    #Usando Regex para obter os valores de 'DataSources' das aplicações contidas no arquivo customization.xml
    $regex = '(?<=/sharepointonline/icon.png","dataSources":\[)(.*?)(?=\],"dependencies":)'
    foreach($json in $connectionReferencesList){
        $matches = [regex]::Match($json, $regex)
        if ($matches.Success) {
            $values = $matches.Groups[1].Value -split '","'
            $values = $values -replace '"',''
            $listNames += $values
        }
    }
    
    #Obtendo os valores de 'Name' dos Workflows contidos no arquivo customization.xml
    foreach ($flow in $workflows) {
        $flowNames += $flow.Workflow.Name
    }

    #Reproduzindo os valores armazenados até aqui
    if ($logView -eq $true) {
        Write-Host "LOG DO PROCESSO:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "solutionPath: $solutionPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "customizationsPath: $customizationsPath" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "solutionName: [$solutionName]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "appName: [$($appNames -join ', ')]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "flowName: [$($flowNames -join ', ')]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "tableName: [$($listNames -join ', ')]" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "FIM DO LOG" -ForegroundColor Yellow
        Write-Host ""
    }

    #Função de checagem de padrões
    $errorCounter = 0
    function CheckPrefix($prefixes, $value) {
        return ($prefixes | Where-Object { $value.StartsWith($_) }) -ne $null
    }

    # Validações 
    $solutionPrefixes = "DSV_SOL", "HOM_SOL", "PRD_SOL"
    if (-not (CheckPrefix $solutionPrefixes $solutionName)) {
        $errorCounter++
        if ($logView -eq $true) {
            Write-Host "SOLUCAO '$solutionName' NAO CONFORME" -ForegroundColor Red
        }
    }
    $flowPrefixes = "DSV_FLW_", "HOM_FLW_", "PRD_FLW_"
    foreach ($flow in $flowNames) {
        if (-not (CheckPrefix $flowPrefixes $flow)) {
            $errorCounter++
            if ($logView -eq $true) {
                Write-Host "FLOW '$flow' NAO CONFORME" -ForegroundColor Red
            }
        }
    }
    $appPrefixes = "DSV_APP_", "HOM_APP_", "PRD_APP_", "DSV_LIB_", "HOM_LIB_", "PRD_LIB_"
    foreach ($app in $appNames) {
        if (-not (CheckPrefix $appPrefixes $app)) {
            $errorCounter++
            if ($logView -eq $true) {
                Write-Host "APLICATIVO '$app' NAO CONFORME" -ForegroundColor Red
            }
        }
    }
    $listPrefixes = "DSV_LST_", "HOM_LST_", "PRD_LST_"
    foreach ($list in $listNames) {
        if (-not (CheckPrefix $listPrefixes $list)) {
            $errorCounter++
            if ($logView -eq $true) {
                Write-Host "LISTA '$list' NAO CONFORME" -ForegroundColor Red
            }
        }
    }

    #Apagando pasta temporária anterior
    Remove-Item -Path "$($env:TEMP)\tempFolder" -Recurse -Force

    #Retornado resposta
    if ($errorCounter -gt 0) {
        Write-Host "PADROES NAO CONFORMES" -ForegroundColor Red
        return $false
    } else {
        Write-Host "PADROES NOS CONFORMES" -ForegroundColor Green
        return $true
    }
}
