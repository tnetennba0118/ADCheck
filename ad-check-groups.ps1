<#
.SYNOPSIS
   <A brief description of the script>
.DESCRIPTION
   <A detailed description of the script>
.PARAMETER <paramName>
   <Description of script parameter>
.EXAMPLE
   <An example of using the script>
#>
function FileChk
{
	Param ($filename)
	
	$mf = get-childitem $filename
	$i = 0
	While (test-path $filename)
	{
		$i++
		$filename = "$($mf.directoryname)\$($mf.basename)`($($i)`)$($mf.extension)"
	}
	return $filename
}

$importfile = "\\location\dfs$\Applicaties\Samenwerking\Powershell\IE-keys\users.csv"
$logfile = "\\location\dfs$\Applicaties\Samenwerking\Powershell\IE-Keys\usergroups-" + (Get-Date -Format dd-MM-yyyy) + ".log"
$err = 0
if (Test-Path $logfile)
{
	$logfile = FileChk $logfile
}

"Script gestart op " + (Get-Date -Format dd-MM-yyyy-HH:mm) + "" | Out-File -FilePath $logfile -Append -NoClobber
"" | Out-File -FilePath $logfile -Append -NoClobber

try { $csv = Import-Csv -Path $importfile -Delimiter "," }
catch
{
	write-output "File met users `"$importfile`" niet gevonden" | Out-File -FilePath $logfile -Append -NoClobber
	"" | Out-File -FilePath $logfile -Append -NoClobber
	$err = 1
	exit
}


Write-Output $csv | Out-File -FilePath $logfile -Append -NoClobber
#$groups = $csv | select -Unique group

<#foreach ($groep in $groups)
{
	("`n{0}" -f $groep.group) | Out-File -FilePath $logfile -Append -NoClobber
	
	$A = $csv | where { $_.Group -eq $groep.group } | select samAccountName
	
	foreach ($naam in $A)
	{
		if ($naam.samAccountName -eq "")
		{
			$err = 1
			"Er zit een fout in de CSV-file. AD-group `"" + $groep.group + "`" niet in orde" | Out-File -FilePath $logfile -Append -NoClobber
			"Deze groep wordt daarom overgeslagen" | Out-File -FilePath $logfile -Append -NoClobber
			break
		}
	}
	
	try { $B = Get-ADGroupMember $groep.group | select samAccountName }
	catch
	{	
		"Groep `"" + $groep.group + "`" niet gevonden in de AD" | Out-File -FilePath $logfile -Append -NoClobber
		"" | Out-File -FilePath $logfile -Append -NoClobber
		$err = 1
		$A = $null
	}
	
	if ($A.SamAccountName -eq "<leeg>" -and $B -eq $null)
	{
		$groep.group + " is in orde" | Out-File -FilePath $logfile -Append -NoClobber
	}
	elseif ($A.samAccountName -eq "<leeg>")
	{
		foreach ($user in $B)
		{
			$user.samAccountName + " wordt verwijderd uit AD-group " + $groep.group | Out-File -FilePath $logfile -Append -NoClobber
			try { Remove-ADGroupMember $groep.group -Members $user.SamAccountName -Confirm:$false }
			catch
			{
				"Verwijderen van user " + $user.SamAccountName + " uit de groep " + $groep.group + " is mislukt" | Out-File -FilePath $logfile -Append -NoClobber
				"Reason: " + ($_.Exception.Message).replace("`n", "") | Out-File -FilePath $logfile -Append -NoClobber
			}
			$err = 1
		}
	}
	if ($A.samAccountName -ne "<leeg>" -and $B -eq $null -and $A -ne $null)
	{
		foreach ($user in $A)
		{
			$user.samAccountName + " wordt toegevoegd aan AD-group " + $groep.group | Out-File -FilePath $logfile -Append -NoClobber
			try { Remove-ADGroupMember $groep.group -Members $user.SamAccountName -Confirm:$false }
			catch
			{
				"Verwijderen van user " + $user.SamAccountName + " uit de groep " + $groep.group + " is mislukt" | Out-File -FilePath $logfile -Append -NoClobber
				"Reason: " + ($_.Exception.Message).replace("`n", "") | Out-File -FilePath $logfile -Append -NoClobber
			}
			$err = 1
		}
	}
	
	if ($A.SamAccountName -ne "<leeg>" -and $B -ne $null -and $A -ne $null)
	{
		
		$C = Compare-Object $A.samAccountName $B.samAccountName
		
		if ($C)
		{
			$C | foreach {
				if ($_.SideIndicator -eq "=>")
				{
					("verwijderen user `"{0}`"" -f $_.InputObject) | Out-File -FilePath $logfile -Append -NoClobber
					try { Remove-ADGroupMember $groep.group -Members $_.InputObject -Confirm:$false }
					catch
					{
						"Verwijderen van user " + $_.InputObject + " uit de groep " + $groep.group + " is mislukt" | Out-File -FilePath $logfile -Append -NoClobber
						"Reason: " + ($_.Exception.Message).replace("`n", "") | Out-File -FilePath $logfile -Append -NoClobber
					}
					$err = 1
					
				}
				else
				{
					if ($_.InputObject -ne "")
					{
						("toevoegen user `"{0}`"" -f $_.InputObject) | Out-File -FilePath $logfile -Append -NoClobber
						try { Add-ADGroupMember $groep.group -Members $_.InputObject -Confirm:$false }
						catch
						{
							"Toevoegen van user " + $_.InputObject + " aan de groep " + $groep.group + " is mislukt" | Out-File -FilePath $logfile -Append -NoClobber
							"Reason: " + ($_.Exception.Message).replace("`n", "") | Out-File -FilePath $logfile -Append -NoClobber
						}
						$err = 1
					}
				}
			}
			"" | Out-File -FilePath $logfile -Append -NoClobber
		}
		else
		{
			$groep.group + " is in orde" | Out-File -FilePath $logfile -Append -NoClobber
			
		}
	}
	"" | Out-File -FilePath $logfile -Append -NoClobber
}
if ($err -eq 1)
{
	"Mail naar helpdesk" | Out-File -FilePath $logfile -Append -NoClobber
	Send-MailMessage -To helpdesk, opperhoofd -Subject "Script adusercheck heeft gedraaid" -Body "Script adusercheck om groepen te controleren of de goede users lid zijn heeft gedraaid. Er zijn afwijkingen gevonden, controleer de logfile" -From no-reply -attachments $logfile -Port 25 -SmtpServer smtp-server
}
else
{
	"Geen afwijkingen gevonden" | Out-File -FilePath $logfile -Append -NoClobber
}#>
