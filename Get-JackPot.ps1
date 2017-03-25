<#PSScriptInfo

  .VERSION 2.0.0
  .GUID 0fd916fe-3a0d-48c4-a196-18ea085e071f
  .AUTHOR Craig Dayton
  .COMPANYNAME Example.com
  .COPYRIGHT Absolute Zero
  .TAGS 
  .LICENSEURI 
  .PROJECTURI https://github.com/cadayton/JackPot
  .ICONURI 
  .EXTERNALMODULEDEPENDENCIES 
  .REQUIREDSCRIPTS 
  .EXTERNALSCRIPTDEPENDENCIES 
  .RELEASENOTES

#>

<#
  .SYNOPSIS
    Display the current Washington State lottery game results and optionally stores the 
    results in a local history file.

  .DESCRIPTION
    Displays Washington lottery game results by invoking a web request to
    http://www.walottery.com/WinningNumbers and extracts the game results
    onto the console and optionally saves the results locally.

    Picks game winning numbers based on frequency of past winning numbers.

  .PARAMETER game
    Displays all the history results of a specified lottery game in the Out-Gridview.

  .PARAMETER online
    Displays the current lottery game results on the console.

  .PARAMETER update
    Displays the current lottery game results on the console and updates
    the history file.

  .PARAMETER all
    Displays all the history lottery game results in a Out-Gridview.

  .PARAMETER picker
    Used in combination with the 'game' option to pick a set of winning
    numbers for a game based on frequency of past winning numbers.

  .PARAMETER count
    Used in combination with the 'game' and 'picker' option to generate
    a specified set of numbers.  The default is 1.

  .INPUTS
    A history csv file named, JackPot-Results.csv

    http://www.walottery.com/WinningNumbers

  .OUTPUTS
    A history csv file named, JackPot-Results.csv
    
  .EXAMPLE
    Get-JackPot

    Displays the last 12 game history records on the console.

  .EXAMPLE
    Get-JackPot -game PowerBall

    Displays all the PowerBall records in the history file. 

  .EXAMPLE
    Get-JackPot -online

    Queries the lottery web page and then extracts and displays the
    current game results.

  .EXAMPLE
    Get-JackPot -update

    Queries the lottery web page and then extracts and displays the
    current game results.  The history file is then updated with new
    game results.
  
  .EXAMPLE
    Get-JackPot -game PowerBall -picker -count 3

    Generates 3 sets of winning numbers for the PowerBall game.

    Example Output:
      PowerBall Game (1):  16 23 25 32 64 09
      PowerBall Game (2):  25 28 40 52 64 21
      PowerBall Game (3):  12 23 52 64 69 20

  .NOTES

    Author: Craig Dayton
    Updated: 03/24/2017 - Added feature to generate a set of winning numbers
    Updated: 03/24/2017 - Game record duplication algorthim modified
    Updated: 03/23/2017 - Fixed some logic errors
    Updated: 03/22/2017 - initial release.
    
#>


# Get-JackPot Params
  [cmdletbinding()]
    Param(
      [Parameter(Position=0,
        Mandatory=$false,
        HelpMessage = "Enter a lottery game name (i.e. PowerBall)",
        ValueFromPipeline=$True)]
        #[ValidateNotNullorEmpty("^[a-zA-Z]{12}$")]
        [string]$game,
      [Parameter(Position=1,
        Mandatory=$false,
        HelpMessage = "Display Online Lottery Results",
        ValueFromPipeline=$True)]
        [ValidateNotNullorEmpty()]
        [switch]$online,
      [Parameter(Position=2,
        Mandatory=$false,
        HelpMessage = "Display Online Lottery Results & update history file",
        ValueFromPipeline=$True)]
        [ValidateNotNullorEmpty()]
        [switch]$update,
      [Parameter(Position=3,
        Mandatory=$false,
        HelpMessage = "Display all game history file records",
        ValueFromPipeline=$True)]
        [ValidateNotNullorEmpty()]
        [switch]$all,
      [Parameter(Position=4,
        Mandatory=$false,
        HelpMessage = "Display all game history file records",
        ValueFromPipeline=$True)]
        [ValidateNotNullorEmpty()]
        [switch]$picker,
      [Parameter(Position=5,
        Mandatory=$false,
        HelpMessage = "Number of games",
        ValueFromPipeline=$True)]
        [ValidateNotNullorEmpty()]
        [int]$count = 1
   )
#

# Declarations
  $URI1 = "http://www.walottery.com/WinningNumbers";

  [String[]]$JackPotHeader  = "Game", "DrawDate","DrawDay", "Numbers", "Multiplier", "JackPot", "NextDraw", "NextDay";
  [String[]]$MultiHeader    = "Game", "HotNums","Multiplier";
  [String[]]$StdHeader      = "Game", "HotNums";
  [String[]]$DailyHeader    = "Game", "Pos1","Pos2","Pos3";
  
  # Most frequent winning numbers per game
    $HotArray = New-Object System.Collections.ArrayList;
    $HotArray.Add('PowerBall,03 12 16 23 25 28 32 33 40 52 64 69,02 03 05 06 09 10 12 17 19 20 21 25') | Out-Null;
    $HotArray.Add('MegaMillions,02 11 20 25 29 31 35 41 44 45 49 51,01 02 03 04 06 07 08 09 10 12 14 15') | Out-Null;
    $HotArray.Add('Lotto,28 26 03 37 47 13 17 27 39 49 19 25 43 21 20 08 41 12 01 24 10') | Out-Null;
    $HotArray.Add('Hit5,35 37 13 33 14 23 17 12 27 07 28 02 21 03 11 34 38 10 31') | Out-Null;
    $HotArray.Add('Match4,19 18 24 05 13 08 04 02 16 07 21 06') | Out-Null;
    $HotArray.Add('DailyGame,8 5 4 7 1,7 2 9 6 5,8 0 7 2 4') | Out-Null;
  #

#

# Functions

  function Convert-fileToCSV {
    param ([string]$fname)

    $bufLine  = $null;
    $game = $Global:game;
    [bool]$needNums = $true;
    $DrawDate, $DrawDay, $Numbers, $Multiplier, $Prize, $NextDate, $NextDay = $null;
    get-content -Path $fname | ForEach-Object {  # process each input line
      # evaluate any non-blank line
      if ($_ -notmatch "^ ") {
        $curLine = $_;
        
        if ($curLine -match "Latest Draw:" -and $DrawDate -eq $null) {
          $junk,$ld = $curline.Split(":");
          $day,$date = $ld.Split("/");
          $DrawDay = $day;
          $DrawDate = Get-Date $date -format yyyy-MM-dd;
        }

        if ($curLine -match "^\d" -and $needNums) {
          $Numbers += $curLine + " ";
        }

        if ($curLine -match "Power Play" -and $Multiplier -eq $null) {
          $Multiplier = $curLine.Substring(11,3);
        }

        if ($curLine -match "Megaplier" -and $Multiplier -eq $null) {
          $Multiplier = $curLine.Substring(10,3);
        }

        if ($curLine -match "[$]" -and $Prize -eq $null) {
          $needNums = $false;
          $Prize = $curLine;
        }

        if ($curLine -match "Next Draw:" -and $NextDate -eq $null) {
          $junk,$ld = $curline.Split(":");
          $day,$date = $ld.Split("/");
          if ($date -ne $null ) {
            $NextDay = $day;
            $NextDate = Get-Date $date -format yyyy-MM-dd;
          } else {
            $NextDate = $day;
          };
        }

        if ($curLine -match "Daily" -and $NextDate -eq $null) { $NextDate = $curLine};

      }
    }

    $bufLine  = $game + ";" + $DrawDate + ";" + $DrawDay + ";" + $Numbers + ";";
    $bufLine += $Multiplier + ";" + $Prize + ";" + $NextDate + ";" + $NextDay;
    $bufLine | Out-File -FilePath $temp2 -Append -Encoding ascii;

    if (Test-Path $fname) { Remove-Item -Path $fname };

  }

  function Update-JackPotHistory {
    param ([string]$fname)

    if (Test-Path $JackPot ) {
    
      $histLine  = Get-Content -Path $JackPot | Select-Object -Last 1;
      $currLine  = Get-Content -Path $fname | Select-Object -Last 1;

      if ($histLine -ne $currLine) { # Update history file
        $histLine  = Get-Content -Path $JackPot | Select-Object -Last 12;
        get-content -Path $fname | ForEach-Object {  # process each input line
          $curLine    = $_;
          $curLine24  = $_.Substring(0,23);
          [bool]$duplicate = $false;
          # Elimate duplcate entries in the history file
          $histLine | ForEach-Object {
            $histLine24 = $_.Substring(0,23);
            if ($curLine24 -eq $histLine24) {
              $duplicate = $true;
            }
          }
          if ($duplicate) {} else {
            $curLine | Out-File -FilePath $JackPot -Append -Encoding ascii;
          }
        }
      }
    } else {
      get-content -Path $fname | ForEach-Object {  # process each input line
        $_ | Out-File -FilePath $JackPot -Append -Encoding ascii;
      }
    }
  }

  function Get-WaWebRequest {
    
    $response = Invoke-WebRequest -URI $URI1;

    if ($response.StatusCode -eq "200") {
      Write-Progress -Activity "Processing response from $URI1 ..." -Status "Please wait"

      $Global:game = "PowerBall";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-powerball"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      $Global:game = "MegaMillions";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-megamillions"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      Write-Progress -Activity "Go away" -Completed;

      $Global:game = "Lotto";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-lotto"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      $Global:game = "Hit5";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-hit5"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      $Global:game = "Match4";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-match4"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      $Global:game = "DailyGame";
      Write-Host " Processing $Global:game results"  -ForegroundColor Green
      $data = $($response.ParsedHtml.getElementsByTagName("div") |
                Where-Object classname -eq "game-bucket game-bucket-dailygame"
              );
      $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
      Convert-fileToCSV $temp1;

      <# commented out Keno
        $Global:game = "Keno"; $Global:ID = 7;
        Write-Host " Processing $Global:game results"  -ForegroundColor Green
        $data = $($response.ParsedHtml.getElementsByTagName("div") |
                  Where-Object classname -eq "game-bucket game-bucket-keno"
                );
        $data.innerText | Out-File -FilePath $temp1 -Append -Encoding ascii;
        Convert-fileToCSV $temp1;
      #>

      $currentGames = Import-CSV -Path $temp2 -Delimiter ";" -Header $JackPotHeader;
      $currentGames | Format-Table -AutoSize -Wrap

      if ($update) { Update-JackPotHistory $temp2; };

      if (Test-Path $temp2 ) {
        Remove-Item -Path $temp2 
      };

    } else {
      Write-Host "Received error code: $response.StatusCode from $URI1";
    }

  }

  function Show-JackPotError {
    Write-Host "$JackPot not found"
    Write-Host "Execute 'Get-JackPot -update' to create the history file."
    Write-Host "Get-Help Get-JackPot -full and review the documentation."
  }

  function Get-MultiPicker {
    $HotPB = Import-CSV -Path $HotNums -Delimiter "," -Header $MultiHeader |
      Where-Object {$_.Game -match $game };
    for ($i = 1; $i -le $count; $i++) {
      $topNums  = $HotPB.HotNums;
      $topMulti = $HotPB.Multiplier;
      $top1     = $topNums.Split(" ");
      $top2     = $topMulti.Split(" ");
      $sel1     = Get-Random -InputObject $top1 -Count 5
      $sel2     = Get-Random -InputObject $top2 -Count 1
      $sela     = $sel1 | Sort-Object;
      $selb     = [system.String]::Join(" ",$sela)
      $sel      = $selb + " " + $sel2;
      Write-Host "$game Game ($i):  $sel" -ForegroundColor Green
    }
  }

  function Get-NumPicker {
    Param ([int]$numcnt)

    $HotPB = Import-CSV -Path $HotNums -Delimiter "," -Header $StdHeader |
      Where-Object {$_.Game -match $game };
    for ($i = 1; $i -le $count; $i++) {
      $topNums  = $HotPB.HotNums;
      $top1     = $topNums.Split(" ");
      $sel1     = Get-Random -InputObject $top1 -Count $numcnt
      $sela     = $sel1 | Sort-Object;
      $selb     = [system.String]::Join(" ",$sela)
      Write-Host "$game Game ($i):  $selb" -ForegroundColor Green
    }
  }

  function Get-GameNumbers {

    if (Test-Path $HotNums) {} else { 
      # Create the file dynamically
      $HotArray | ForEach-Object {
        $_ | Out-File -FilePath $HotNums -Append -Encoding ascii;
      }
    }

    switch ($game) {
      "PowerBall" {
        Get-MultiPicker;
      }
      "MegaMillions" {
        Get-MultiPicker;
      }
      "Lotto" {
        Get-NumPicker 6
      }
      "Hit5" {
        Get-NumPicker 5
      }
      "Match4" {
        Get-NumPicker 4
      }
      "DailyGame" {
        $HotPB = Import-CSV -Path $HotNums -Delimiter "," -Header $DailyHeader |
          Where-Object {$_.Game -match $game };
        for ($i = 1; $i -le $count; $i++) {
          $topPos1  = $HotPB.Pos1;
          $topPos2  = $HotPB.Pos2;
          $topPos3  = $HotPB.Pos3;
          $pos1     = $topPos1.Split(" ");
          $pos2     = $topPos2.Split(" ");
          $pos3     = $topPos3.Split(" ");
          $sel1     = Get-Random -InputObject $pos1 -Count 1
          $sel2     = Get-Random -InputObject $pos2 -Count 1
          $sel3     = Get-Random -InputObject $pos3 -Count 1
          $sel      = $sel1 + " " + $sel2 + " " + $sel3;
          Write-Host "$game Game ($i):  $sel" -ForegroundColor Green
        }

      }
      Default {
        Write-Host "$game not found" -ForegroundColor Red
        Write-Host "Valid game names are: 'PowerBall, MegaMillions, Hit5, Match4, and DailyGame' " -ForegroundColor Green
      }
    }

  }

#

# Main Routine

  $sPath    = Get-Location;
  $temp1    = "$sPath\temp1.txt";
  $temp2    = "$sPath\temp2.txt";
  $JackPot  = "$sPath\JackPot-Results.csv";
  $HotNums  = "$sPath\JackPot-HotNums.csv";

  if (Test-Path $temp1 ) {
    Remove-Item -Path $temp1 
  };

  if (Test-Path $temp2 ) {
    Remove-Item -Path $temp2 
  };

  $choice = $null;
  if ($online -or $update) { $choice = "WebRequest"};
  if ($game -and (!($picker))) { $choice = "GameHistory"};
  if ($game -and $picker) { $choice = "GamePicker"};
  if ($all) { $choice = "AllHistory"};

  switch ($choice) {
    "WebRequest" {
      Get-WaWebRequest;
    }
    "GameHistory" {
      if (Test-Path $JackPot) {
        $currentGames = Import-CSV -Path $JackPot -Delimiter ";" -Header $JackPotHeader |
          Where-Object {$_.Game -match $game };
        if ($currentGames) { 
          $currentGames |  Out-GridView -Title "$game at $URI1"
        } else {
          Write-Host "$game not found" -ForegroundColor Red
          Write-Host "Valid game names are: 'PowerBall, MegaMillions, Hit5, Match4, and DailyGame' " -ForegroundColor Green
       } 
      } else { Show-JackPotError; }

    }
    "GamePicker" {
      Get-GameNumbers;
    }
    "AllHistory" {
      if (Test-Path $JackPot) {
        Import-CSV -Path $JackPot -Delimiter ";" -Header $JackPotHeader | Out-GridView -Title "Listing of lottery game records"
      } else { Show-JackPotError; }
    }
    Default {
      if (Test-Path $JackPot) {
        $currentGames = Import-CSV -Path $JackPot -Delimiter ";" -Header $JackPotHeader;
        $currentGames | Select-Object -Last 12 | Format-Table -AutoSize -Wrap;
      } else { Show-JackPotError; }
    }
  }

#