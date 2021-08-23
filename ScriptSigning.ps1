<#
    Prereq https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.1/Git-2.33.0-64-bit.exe

    Version 1.1 - Some typos fixed
    Version 1.0 - Initial
#>

$Version = "1.1"

$env:GIT_REDIRECT_STDERR = '2>&1'

# Load xaml
[System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework") | Out-Null

[xml]$xaml  = Get-Content -Path $PSScriptRoot\Form.xaml
$manager    = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xaml.NameTable
$manager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml");
$xamlReader = New-Object System.Xml.XmlNodeReader $xaml
$window     = [Windows.Markup.XamlReader]::Load($xamlReader)

# Create variables by Name=
$xaml.SelectNodes("//*[@*[contains(translate(name(.), 'n', 'N'), 'Name')]]") | ForEach-Object {
   New-Variable  -Name $_.Name -Value $Window.FindName($_.Name) -Force -ErrorAction SilentlyContinue -Scope Global
}

$script:i = 0
$script:j = 0

$accesstoken = 'XCpJ2SPx4c2tczyt6Yrc'
$ProjectId =  '28764161'
$script:projectName = "CS-Pipeline"
$script:basePath = "C:\tmp\GitLab"

$tbBasePath.text = $script:basePath
$tbAccessToken.text = $accesstoken
$tbProjectName.text =  $script:projectName
$tbProjectid.text = $ProjectId

$apiUrl = "http://gitlab.com/api/v4/projects" 
 
$rtbLog.IsReadOnly = $true

# Loaded window handler 
$window.Add_Loaded({

    $rtbLog.AppendText("========= Start ==============") 

    $rtbLog.AppendText("`n[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Script version: $Version`n")

    # Check git
    $gitver = & git --version

    if ($gitver -match "git version"){

        $rtbLog.AppendText("========= Git ==============`n")  
        $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $($gitver)`n")
        $rtbLog.ScrollToEnd()
         
    }
    else {
    
        $rtbLog.AppendText("`n[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git is not installed`n")
        $rtbLog.ScrollToEnd()  
    }

   # Get the code signing certs & paste them in the combobox items
   $script:cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert 
   
   $cmbCerts.ItemsSource = $script:cert

   $cmbCerts.DisplayMemberPath = "Subject"
    
   $cmbCerts.SelectedIndex = 0

   $script:cert = $script:cert[0]

   $rtbLog.AppendText("========= Cert ==============`n")
      
   $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Selected certificarte: $(
        
                if ($cmbCerts.SelectedItem.FriendlyName -eq ''){'Friendly name: --'}else{"Friendly name: $cmbCerts.SelectedItem.FriendlyName"}
                "; Thumbprint: $($cmbCerts.SelectedItem.Thumbprint)"
   )`n")
   
   $rtbLog.ScrollToEnd()
})

# Combobox dropdown handler
$cmbCerts.Add_DropDownClosed({
   
    $script:cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | ? {$_.Thumbprint -eq $($cmbCerts.SelectedItem.Thumbprint)}

    $rtbLog.AppendText("`n========= Cert ==============`n")

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Selected certificate: $(
        
                if ($cmbCerts.SelectedItem.FriendlyName -eq ''){'Friendly name: --'}else{"Friendly name: $($cmbCerts.SelectedItem.FriendlyName)"}
                "; Thumbprint: $($cmbCerts.SelectedItem.Thumbprint)"
    )`n")

   $rtbLog.ScrollToEnd()
}) 

# Connect button handler
$btnConnect.Add_Click({

    $rtbLog.AppendText("========= Connect =============`n") 
         	
    try {

       $projectName = $tbProjectName.text

       $url = $apiUrl + "?search=" + $projectName 
   
       $res = Invoke-WebRequest $url -Headers @{ 'PRIVATE-TOKEN'=$accesstoken} 

        if ($res.StatusCode -eq '200'){
           
            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Server response:`t$($res.StatusCode) - connected`n") 
            $rtbLog.ScrollToEnd() 
        }
    }
    catch {
            $ex = $_.Exception
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
    }

})

# FindPrj button click handler
$btnFindPrj.Add_Click({

      $rtbLog.AppendText("========= Projects =============`n") 

      $url = $apiUrl + "?search=" + $script:projectName 

      $script:prj = Invoke-RestMethod -Headers @{ 'PRIVATE-TOKEN'=$accesstoken}  -Uri $url 

      $rtbLog.AppendText("$(($script:prj | Sort-Object -Property id | Format-Table -Property id, name, web_url -HideTableHeaders | Out-String).trim())`n")  
      $rtbLog.ScrollToEnd()   
})

# GetPrj button click handler
$btnGetPrj.Add_Click({

    $rtbLog.AppendText("========= Project: $ProjectId =============`n") 

    $script:prj | ? {$_.id -eq $ProjectId} | ForEach-Object {

        #$name =  $_.name
        $namespace=  $_.path_with_namespace.Replace('`\','/')
        $script:url = $_.http_url_to_repo
        $script:scrtemp = join-path $script:basePath $namespace

        # Create a local folder if it is not exist
        if (!(Test-Path -Path $basePath -ErrorAction SilentlyContinue)){

            New-Item -ItemType Directory -Path $basePath -Force

            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $basePath created.`n")
        }

        # Clear the folder if it is not empty
        if (Test-Path -Path $script:scrtemp -ErrorAction SilentlyContinue){

             $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $script:scrtemp is not empty. It will be removed`n")
                
             Remove-Item -Path $script:scrtemp -Force -Recurse

             $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $script:scrtemp removed`n")
        }

        # Clone repo
        Invoke-Command { git clone $script:url $script:scrtemp} 
        
        # Check the content
        if (Test-Path -Path $script:scrtemp -ErrorAction SilentlyContinue){

            # Add upstream
            Invoke-Command {git remote add upstream $script:url} 
                                        
            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Cloned: $($script:url) ---> $($script:scrtemp)`n")  
        }

     } 

     $rtbLog.ScrollToEnd()   
     
})

# UpdPrj button click handler
$btnUpdPrj.Add_Click({

        $rtbLog.AppendText("========= Project update =============`n") 

        Set-Location $script:scrtemp

        # Get *.ps1 files and add changes in the working directory
        Get-ChildItem -path $script:scrtemp -Filter "*.ps1" | % {

            Invoke-Command {git add $($_.name) } 
          
            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git add --> $($_.name) added `n")
        }
          
        # Add commit message
        $res = Invoke-Command {git commit --message "[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] - scripts signed"}

        $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git commit --> $res`n")
        
        # Push
        $res = Invoke-Command {git push}

        $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git push --> $res`n")

        $rtbLog.AppendText("========= Project updated =============`n") 

        $rtbLog.ScrollToEnd()  
})

# Sign button click handler
$btnSign.Add_Click({

    $rtbLog.AppendText("========= Signing =============`n") 

    Get-ChildItem -Path $script:scrtemp -filter "*.ps1" -Recurse | % {

       $res = Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $script:cert -IncludeChain all -Force

       if ($res){

         $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $($res.SignerCertificate.Thumbprint) -> $($res.Path) : $($res.Status)`n")
         
       }

     }

     $rtbLog.ScrollToEnd()
})

# CertInfo button click handler 
$btnCertInfo.Add_Click({

   $rtbLog.AppendText("========= Cert =============`n") 

   $script:cert.Extensions | % { 
        
      $rtbLog.AppendText("$($_.oid.FriendlyName ):`t$($_.Format(1))") 
      $rtbLog.ScrollToEnd() 

   }

   $rtbLog.ScrollToEnd()

})

# ClearLog button click handlwe
$btnClearLog.Add_Click({

    $rtbLog.Document.Blocks.Clear()
    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Log cleared`n") 
    $rtbLog.ScrollToEnd() 
})

# BasePath textbox changed handler
$tbBasePath.Add_TextChanged({
    
    $script:i++

    $script:basePath = $tbBasePath.text

    if ($script:i -gt 1){
        $rtbLog.Undo()
    }

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Clone folder changed to $script:basePath $i`n")
    $rtbLog.ScrollToEnd()
})

# ProjectName textbox changed handler
$tbProjectName.Add_TextChanged({

    $script:j++

    $script:ProjectName = $tbProjectName.text

    if ($script:j -gt 1){
        $rtbLog.Undo()
    }

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Project name changed to $script:ProjectName`n")
    $rtbLog.ScrollToEnd()
})

# Show window
$window.ShowDialog()



