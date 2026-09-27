$ErrorActionPreference="Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8765

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()

Start-Process "http://127.0.0.1:$port/"

Write-Host "JaiveerCPP running. Keep this window open." -ForegroundColor Green

while($listener.IsListening){

    $ctx = $listener.GetContext()

    try{

        $path = $ctx.Request.Url.AbsolutePath

        # =========================
        # OPEN QUESTION IN VS CODE
        # =========================

        if($path -eq "/open"){

            $id = $ctx.Request.QueryString["id"]
            $question = $ctx.Request.QueryString["question"]

            if($id -notmatch '^\d+$'){
                throw "Invalid question number"
            }

            $file = Join-Path $root ("solutions\Q{0:D3}.cpp" -f [int]$id)

            # Create solutions folder if missing
            if(-not (Test-Path -LiteralPath (Split-Path $file))){

                New-Item `
                    -ItemType Directory `
                    -Path (Split-Path $file) `
                    -Force | Out-Null
            }

            # Create question file automatically
            if(-not (Test-Path -LiteralPath $file)){

                $header = @"
// JaiveerCPP — Question $id
// $question

"@

                [IO.File]::WriteAllText(
                    $file,
                    $header,
                    [Text.UTF8Encoding]::new($false)
                )
            }

            # Find VS Code
            $codeCmd = Get-Command code -ErrorAction SilentlyContinue

            if($codeCmd){

                Start-Process `
                    -FilePath $codeCmd.Source `
                    -ArgumentList "--reuse-window","`"$file`""
            }
            elseif(Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"){

                Start-Process `
                    -FilePath "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" `
                    -ArgumentList "--reuse-window","`"$file`""
            }
            else{

                throw "VS Code command 'code' was not found"
            }

            $out = "Opened Q$id"

            $bytes = [Text.Encoding]::UTF8.GetBytes($out)

            $ctx.Response.StatusCode = 200
            $ctx.Response.ContentType = "text/plain; charset=utf-8"

            $ctx.Response.OutputStream.Write(
                $bytes,
                0,
                $bytes.Length
            )

            $ctx.Response.Close()

            continue
        }

        # =========================
        # SERVE WEBSITE
        # =========================

        if($path -eq "/" -or $path -eq "/index.html"){

            $file = Join-Path $root "index.html"
        }
        else{

            $file = Join-Path $root ($path.TrimStart("/"))
        }

        if(-not (Test-Path -LiteralPath $file)){

            throw "Page not found"
        }

        $bytes = [IO.File]::ReadAllBytes($file)

        if($file.EndsWith(".html")){

            $ctx.Response.ContentType = "text/html; charset=utf-8"
        }
        else{

            $ctx.Response.ContentType = "text/plain; charset=utf-8"
        }

        $ctx.Response.StatusCode = 200

        $ctx.Response.OutputStream.Write(
            $bytes,
            0,
            $bytes.Length
        )

        $ctx.Response.Close()
    }

    catch{

        Write-Host (
            "ERROR: " + $_.Exception.Message
        ) -ForegroundColor Red

        try{

            $msg = [Text.Encoding]::UTF8.GetBytes(
                $_.Exception.Message
            )

            $ctx.Response.StatusCode = 500
            $ctx.Response.ContentType = "text/plain; charset=utf-8"

            $ctx.Response.OutputStream.Write(
                $msg,
                0,
                $msg.Length
            )

            $ctx.Response.Close()
        }
        catch{}
    }
}