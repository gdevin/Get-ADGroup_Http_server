

$ServerThreadCode = {

Import-Module activedirectory
Function Get-ADNestedGroupMembers { 

param ( 
[Parameter(ValuefromPipeline=$true,mandatory=$true)][String] $GroupName, 
[int] $nesting = -1, 
[int] $circular = $null, 
[string] $existingList 
)

$modules = get-module | select -expand name
    if ($modules -contains "ActiveDirectory") 
    { 
        $list = $null
        $table = $null 
        $nestedmembers = $null 
        $adgroupname = $null     
        $nesting++ 
        Try {
            $ADGroupname = Get-ADGroup $groupname -properties memberof,members
        }
        Catch { }  
        $memberof = $ADGroupname | select -expand memberof 
        write-verbose "Checking group: $($ADGroupname.name)" 
        if ($ADGroupname) 
        {  
            if ($circular) 
            { 
                $nestedMembers = Get-ADGroupMember -Identity $GroupName -recursive 
                $circular = $null 
            } 
            else 
            { 
                $nestedMembers = Get-ADGroupMember -Identity $GroupName | sort objectclass -Descending
                if (!($nestedmembers))
                {
                    $unknown = $ADGroupname | select -expand members
                    if ($unknown)
                    {
                        $nestedmembers=@()
                        foreach ($member in $unknown)
                        {
                        $nestedmembers += get-adobject $member
                        }
                    }

                }
            } 
 
            foreach ($nestedmember in $nestedmembers) 
            { 
                $Props = @{Type=$nestedmember.objectclass;Name=$nestedmember.name;DisplayName="";ParentGroup=$ADGroupname.name;Enabled="";Nesting=$nesting;DN=$nestedmember.distinguishedname;Comment=""} 
                 
                if ($nestedmember.objectclass -eq "user") 
                { 
                    #if ($nestedadmember.samaccountname -ne $null) {
                        #$list = $list + [string]$nestedadmember.samaccountname + "<br> "
                    #}
                    $nestedADMember = get-aduser $nestedmember -properties enabled,displayname 
                    $table = new-object psobject -property $props 
                    $table.enabled = $nestedadmember.enabled
                    $table.name = $nestedadmember.samaccountname
                    $table.displayname = $nestedadmember.displayname
                    $table | select type,name,displayname,parentgroup,nesting,enabled,dn,comment 
                    $list = $list + [string]$nestedADMember.samaccountname + "<br> "
                } 
                elseif ($nestedmember.objectclass -eq "group") 
                {  
                    $table = new-object psobject -Property $props 
                     
                    if ($memberof -contains $nestedmember.distinguishedname) 
                    { 
                        $table.comment ="Circular membership" 
                        $circular = 1 
                    } 
				
                    else 
                    { 
                        $table | select type,name,displayname,parentgroup,nesting,enabled,dn,comment 
                    } 
                    Get-ADNestedGroupMembers -GroupName $nestedmember.distinguishedName -nesting $nesting -circular $circular -existingList $existingList
                
                }
                else 
                { 
                    if ($nestedmember)
                    {
                        $table = new-object psobject -property $props
                        $table | select type,name,displayname,parentgroup,nesting,enabled,dn,comment    
                    }
                }
            }
        }
        else {Write-Warning "Active Directory module is not loaded"}
    }
    Return $existingList + $list
}


    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://*:2345/Get-ADGroup/') 
    $listener.Start()
    
    while ($listener.IsListening) {
       [System.Net.HttpListenerContext]$context = $listener.GetContext() # blocks until request is received
       [System.Net.HttpListenerRequest]$request = $context.Request
       [System.Net.HttpListenerResponse]$response = $context.Response
       $responseString = "<HTML><BODY>"

       ForEach ($key in $request.QueryString.Keys) {        
          If ($key -eq "group") {
             [string]$groupname = $request.QueryString.GetValues($key)
             
             Try {
                $responseString += Get-ADNestedGroupMembers -GroupName $groupname
             }
             Catch { 
                $responseString += "$groupname is invalid!<br> $_.Exception.Message<br>" 
             }

          }
       }
       $responseString += "</BODY></HTML>"
       [byte[]] $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseString)
       $response.ContentLength64 = $buffer.length
       $output = $response.OutputStream
       $output.Write($buffer, 0, $buffer.length)
       $output.Close()
    }
    $listener.Stop()
}                  

# Get-ADNestedGroupMembers -GroupName S-1-5-21-2509641344-1052565914-3260824488-818770

$serverJob = Start-Job $ServerThreadCode
# Wait for it all to complete
while ($serverJob.State -eq "Running") { Start-Sleep -s 1 }


