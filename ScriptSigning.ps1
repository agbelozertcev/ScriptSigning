<#
    Prereq https://github.com/git-for-windows/git/releases/download/v2.33.0.windows.1/Git-2.33.0-64-bit.exe

    Version 1.1 - Some typos fixed
    Version 1.0 - Initial
#>


$Version = "1.1"

$env:GIT_REDIRECT_STDERR = '2>&1'


[System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework") | Out-Null

[xml]$xaml  = Get-Content -Path $PSScriptRoot\Form.xaml
$manager    = New-Object System.Xml.XmlNamespaceManager -ArgumentList $xaml.NameTable
$manager.AddNamespace("x", "http://schemas.microsoft.com/winfx/2006/xaml");
$xamlReader = New-Object System.Xml.XmlNodeReader $xaml
$window     = [Windows.Markup.XamlReader]::Load($xamlReader)

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


$window.Add_Loaded({


    $rtbLog.AppendText("========= Start ==============") 

    $rtbLog.AppendText("`n[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Script version: $Version`n")

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

   $script:cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert 

   
   $cmbCerts.ItemsSource = $script:cert

   $cmbCerts.DisplayMemberPath = "Subject"
    
   $cmbCerts.SelectedIndex = 0

   $script:cert = $script:cert[0]

   $rtbLog.AppendText("========= Cert ==============`n")
      
   $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Selected certificarte: $(
        
                if ($cmbCerts.SelectedItem.FriendlyName -eq ''){'Friendly name: --'}else{"Friendly name: $cmbCerts.SelectedItem.FriendlyName"};
                "Thumbprint: $($cmbCerts.SelectedItem.Thumbprint)"
   )`n")
   
   $rtbLog.ScrollToEnd()
})

$cmbCerts.Add_DropDownClosed({
   
    $script:cert = Get-ChildItem -Path Cert:\CurrentUser\My -CodeSigningCert | ? {$_.Thumbprint -eq $($cmbCerts.SelectedItem.Thumbprint)}

    $rtbLog.AppendText("========= Cert ==============`n")

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Selected certificate: $(
        
                if ($cmbCerts.SelectedItem.FriendlyName -eq ''){'Friendly name: --'}else{"Friendly name: $($cmbCerts.SelectedItem.FriendlyName)"};
                "Thumbprint: $($cmbCerts.SelectedItem.Thumbprint)"
    )`n")

   $rtbLog.ScrollToEnd()
}) 

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

$btnFindPrj.Add_Click({

      $rtbLog.AppendText("========= Projects =============`n") 

      $url = $apiUrl + "?search=" + $script:projectName 

      $script:prj = Invoke-RestMethod -Headers @{ 'PRIVATE-TOKEN'=$accesstoken}  -Uri $url 

      $rtbLog.AppendText("$(($script:prj | Sort-Object -Property id | Format-Table -Property id, name, web_url -HideTableHeaders | Out-String).trim())`n")  
      $rtbLog.ScrollToEnd()   
})

$btnGetPrj.Add_Click({

    $rtbLog.AppendText("========= Project: $ProjectId =============`n") 

    $script:prj | ? {$_.id -eq $ProjectId} | ForEach-Object {

        $name =  $_.name
        $namespace=  $_.path_with_namespace.Replace('`\','/')
        $script:url = $_.http_url_to_repo
        $script:scrtemp = join-path $script:basePath $namespace

        if (!(Test-Path -Path $basePath -ErrorAction SilentlyContinue)){

            New-Item -ItemType Directory -Path $basePath -Force

            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $basePath created.`n")
        }

        if (Test-Path -Path $script:scrtemp -ErrorAction SilentlyContinue){

             $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $script:scrtemp is not empty. It will be removed`n")
                
             Remove-Item -Path $script:scrtemp -Force -Recurse

             $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] $script:scrtemp removed`n")
        }

         Invoke-Command { git clone $script:url $script:scrtemp} 

          
         if (Test-Path -Path $script:scrtemp -ErrorAction SilentlyContinue){

            $res = Invoke-Command { git remote add upstream $script:url} 
                                        
            $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Cloned: $($script:url) ---> $($script:scrtemp)`n")  
          }

     } 

     $rtbLog.ScrollToEnd()   
     
 })

$btnUpdPrj.Add_Click({

        $rtbLog.AppendText("========= Project update =============`n") 

          Set-Location $script:scrtemp

          Get-ChildItem -path $script:scrtemp -Filter "*.ps1" | % {

             Invoke-Command {git add $($_.name) } 
          
             $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git add --> $($_.name) added `n")
 
          }
          
          $res = Invoke-Command {git commit --message "[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] - scripts signed"}

          $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git commit --> $res`n")

          $res = Invoke-Command {git push}

          $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] git push --> $res`n")

          $rtbLog.AppendText("========= Project updated =============`n") 

          $rtbLog.ScrollToEnd()  

})

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

$btnCertInfo.Add_Click({

   $rtbLog.AppendText("========= Cert =============`n") 

   $script:cert.Extensions | % { 
        
      $rtbLog.AppendText("$($_.oid.FriendlyName ):`t$($_.Format(1))") 
      $rtbLog.ScrollToEnd() 

   }

   $rtbLog.ScrollToEnd()

})

$btnClearLog.Add_Click({

    $rtbLog.Document.Blocks.Clear()
    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Log cleared`n") 
    $rtbLog.ScrollToEnd() 
})


$tbBasePath.Add_TextChanged({
    
    $script:i++

    $script:basePath = $tbBasePath.text

    if ($script:i -gt 1){
        $rtbLog.Undo()
    }

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Clone folder changed to $script:basePath $i`n")
    $rtbLog.ScrollToEnd()
})

$tbProjectName.Add_TextChanged({

    $script:j++

    $script:ProjectName = $tbProjectName.text

    if ($script:j -gt 1){
        $rtbLog.Undo()
    }

    $rtbLog.AppendText("[$(Get-date -format "dd.MM.yyyy HH:mm:ss")] Project name changed to $script:ProjectName`n")
    $rtbLog.ScrollToEnd()
})

$window.ShowDialog()



