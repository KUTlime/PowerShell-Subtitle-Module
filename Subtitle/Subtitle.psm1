class Subtitle
{

  # public Property
  [UInt32]$Index

  [TimeSpan]$StartTime

  [TimeSpan]$EndTime

  [String]$Text

  [System.IO.FileInfo]$Path

  # Constructor
  Subtitle([String]$inputText)
  {
    $lines = $inputText -split "`r`n"
    # Fix for more than 3-4 lines.

    [UInt32]$number = 0
    if ([UInt32]::TryParse($lines[0], [ref] $number))
    {
      $this.Index = $number;
    }

    # Replace , with . ?
    $times = $lines[1] -split '\s?-->\s?'
    if ($times.Length -eq 2)
    {
      $tempTimespan = [timespan]::new(0, 0, 0)
      [timespan]::TryParse($times[0], [ref] $tempTimespan)
      $this.StartTime = $tempTimespan
      [timespan]::TryParse($times[1], [ref] $tempTimespan)
      $this.EndTime = $tempTimespan
    }
    else
    {
      Write-Warning -Message "The subtitle index $($this.Index) with line: $($lines[1]) is invalid."
    }

    if ($lines.Length -gt 5)
    {
      throw [System.ArgumentException]::new("Possible subtitle collision. Use split for these lines: $lines")
    }
    $stringBuilder = [System.Text.StringBuilder]::new(200)
    2..($lines.Count - 1) | Foreach-Object { $stringBuilder.AppendLine($lines[$_]) | Out-Null }
    $this.Text = $stringBuilder.ToString();
  }

  # Method
  [Subtitle] ChangeDuration([TimeSpan]$increment)
  {
    $this.StartTime = $this.StartTime + $increment
    $this.EndTime = $this.EndTime + $increment

    return $this
  }

  [string] ToString()
  {
    $stringBuilder = [System.Text.StringBuilder]::new(500)
    $stringBuilder.AppendLine($this.Index)
    $stringBuilder.AppendLine($this.StartTime.ToString("hh\:mm\:ss\,fff") + ' --> ' + $this.EndTime.ToString("hh\:mm\:ss\,fff"))
    $stringBuilder.Append($this.Text)  # The line end is already in the Text property.
    return $stringBuilder.ToString()
  }
}

function Read-Subtitle
{
  <#
      .SYNOPSIS
      Reads subtitles from the input text file.

      .DESCRIPTION
      The Read-Subtitle cmdlet reads subtitles from the input text file or files. This cmdlet can be piped to the Get-ChildItem cmdlet for a batch processing.

      .PARAMETER Path
      Specifies a path to a subtitle file. The input can be a string or a valid instance of the System.IO.FileInfo class.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and returns them into console.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path and reads them one by one. The all subtitle from all files are delay by 5 second and saved into their original files.

      .NOTES
      - This cmdlet uses the OOP approach. The cmdlet use custom made class for the subtitle representation and as the output.
      - If you want synchronize multiple subtitles in batch, process files from one directory only.

      .LINK
      https://github.com/KUTlime/PowerShell-Subtitle-Module

      .INPUTS
      System.String
      System.IO.FileInfo

      .OUTPUTS
      A collection of the Subtitle class instances stored in array. The collection represents the subtitles read from the input file.
  #>


  [CmdletBinding(
    DefaultParameterSetName = 'Basic',
    PositionalBinding = $false,
    HelpUri = 'https://github.com/KUTlime/PowerShell-Subtitle-Module'
  )]
  [Alias('rsub', 'readsub', 'rs', 'Get-Subtitle')]
  [OutputType([Subtitle[]])]
  Param
  (
    # A path to subtitle file of folder where the subtitles are located.
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 0,
      ParameterSetName = 'Basic')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
        if ( -Not ($_ | Test-Path) )
        {
          throw "File or folder does not exist"
        }
        return $true
      })]
    [System.IO.FileInfo]
    $Path
  )

  Begin
  {
  }

  Process
  {
    $subtitles = New-Object 'System.Collections.Generic.List[Subtitle]'

    if ($Path | Test-Path)
    {
      $rawLines = (Get-Content -Path $Path.FullName -Raw) -split "`r`n`r`n"
      $rawLines | ForEach-Object { if ($_ -ne "") { $subtitles.Add([Subtitle]::new($_)) } }
    }
    Write-Debug -Message "The number of subtitles: $($subtitles.Count)"
    foreach ($subtitle in $subtitles)
    {
      $subtitle.Path = $Path
    }
    #$subtitles | ForEach-Object { $_.Path = $Path } -OutVariable 'subtitles'
    Write-Debug -Message "The number of subtitles: $($subtitles.Count)"

    Write-Output $subtitles
  }

  End
  {
  }
}

function Sync-Subtitle
{
  <#
      .SYNOPSIS
      Changes the subtitle timing.

      .DESCRIPTION
      This cmdlet adjust the subtitle timing based on the input time shift. Use FromTime, FromSubtitleIndex, ToTime, ToSubtitleIndex for a partial synchronization.
      You can change timing from, until or between some specific subtitle indexes or subtitle time by combination of these parameters.

      .PARAMETER Subtitle
      Specifies the subtitle collection to adjust. Any collection which can be iterated is supported.

      .PARAMETER TimeShift
      Specifies the subtitle time shift in milliseconds. Use a positive, negative value to delay, advance subtitles respectively. The zero time shift causes error.

      .PARAMETER FromSubtitleIndex
      Specifies the subtitle index from which the subtitles should be adjusted. The default value is 0.

      .PARAMETER FromTime
      Specifies the subtitle time from which the subtitles should be adjusted. The valid formats: 00:00:00,000 or 00:00:00.000. The default value is 00:00:00.000.

      .PARAMETER ToSubtitleIndex
      Specifies the subtitle index to which the subtitles should be adjusted. The valid formats: 00:00:00,000 or 00:00:00.000. The default value is the maximal UInt64 value.

      .PARAMETER ToTime
      Specifies the subtitle time to which the subtitles should be adjusted. The default value is 10675199.02:48:05.4775807.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt | Sync-Subtitle -TimeShift 5000 | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to its original file name.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt | Sync-Subtitle -TimeShift -5000 | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and advance all subtitles by 5 seconds. The result is written to its original file name.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt | Sync-Subtitle -TimeShift 5000 -FromSubtitleIndex 120 | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays subtitles with index 120 and all following subtitles by 5 seconds. The result is written to its original file name.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt | Sync-Subtitle -TimeShift 5000 -FromSubtitleIndex 120 -ToSubtitleIndex 320 | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays subtitles with index 120 to subtitle index 320 by 5 seconds. The subtitle with index 119 and 321 will not be shifted. The result is written to its original file name.

      .EXAMPLE
      Read-Subtitle -Path C:\MyMovies\SomeMovie\SomeMovie.srt | Sync-Subtitle -TimeShift 5000 -FromSubtitleTime '00:12:13.000' -ToSubtitleTime '01:02:03.000' | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles between time starting on 12 min 13 second inclusively to 1 hour 2 minutes and 3 seconds inclusively by 5 seconds. The subtitle before and after this interval will not be shifted. The result is written to its original file name.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path and reads them one by one. The all subtitle from all files are delay by 5 second and saved into their original files. The result is written to their original files.

      .NOTES
      - This cmdlet uses the OOP approach. The cmdlet use custom made class for the subtitle representation and as the output.
      - If you want synchronize multiple subtitles in batch, process files from one directory only.
      - A time shift uses millisecond as unit. 1 second = 1000 milliseconds. Use -TimeShift 5000 for 5 second delay or -TimeShift 5000 for 5 second advance of the subtitles.

      .LINK
      https://github.com/KUTlime/PowerShell-Subtitle-Module

      .INPUTS
      Subtitle
      Subtitle[]

      .OUTPUTS
      An adjusted collection of the Subtitle class instances stored in array. The collection represents the subtitles read from the input file.
  #>


  [CmdletBinding(
    DefaultParameterSetName = 'Basic',
    PositionalBinding = $false,
    HelpUri = 'https://github.com/KUTlime/PowerShell-Subtitle-Module'
  )]
  [Alias('ssub', 'syncsub', 'ss')]
  [OutputType([Subtitle[]])]
  param
  (
    # A collection of subtitles to synchronize.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromPipeline = $true,
      ValueFromRemainingArguments = $false,
      Position = 0)]
    [ValidateNotNull()]
    [ValidateScript( {
        if ( ($_.Count -eq 0) )
        {
          throw "The subtitle collection is empty"
        }
        return $true
      })]
    [Object[]]
    $Subtitle,

    # A number of millisecond for subtitle time shift.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 1)]
    [ValidateNotNull()]
    [ValidateScript( {
        if ( ($_.Count -eq 0) )
        {
          throw "The timeshift is zero."
        }
        return $true
      })]
    [Int64]
    $TimeShift,

    # A positive number which identifies the subtitle index from the synchronization should be processed.
    [Parameter(
      Mandatory = $false,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 2)]
    [ValidateNotNull()]
    [UInt64]
    $FromSubtitleIndex = 0,

    # A positive time from the subtitle should be processed. The valid formats: 00:00:00,000 or 00:00:00.000.
    [Parameter(
      Mandatory = $false,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 3)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
        $validTimeSpan = [TimeSpan]::new(0, 0, 0)
        if ( ([TimeSpan]::TryParse($_, [ref] $validTimeSpan) -eq $false) )
        {
          throw "Validation of the FromTime parameter failed. Try use format 00:00:00,000 or 00:00:00.000 with `".`" as delimiter at the end."
        }
        return $true
      })]
    [String]
    $FromTime = ([TimeSpan]::new(0, 0, 0)).ToString("hh\:mm\:ss\.fff"),

    # A positive number which identifies the subtitle index from the synchronization should be processed.
    [Parameter(
      Mandatory = $false,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 4)]
    [ValidateNotNull()]
    [UInt64]
    $ToSubtitleIndex = [UInt64]::MaxValue,

    # A positive time until to the subtitle should be processed. The valid formats: 00:00:00,000 or 00:00:00.000.
    [Parameter(
      Mandatory = $false,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      Position = 5)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
        $validTimeSpan = [TimeSpan]::new(0, 0, 0)
        if ( ([TimeSpan]::TryParse($_, [ref] $validTimeSpan) -eq $false) )
        {
          throw "Validation of the FromTime parameter failed. Try use format 00:00:00,000 or 00:00:00.000 with `".`" as delimiter at the end."
        }
        return $true
      })]
    [String]
    $ToTime = ([TimeSpan]::MaxValue.ToString("hh\:mm\:ss\.fff"))
  )

  Begin
  {
    $timeSpan = [TimeSpan]::FromMilliseconds($TimeShift)
    $fromTimeSpan = [TimeSpan]::new(0, 0, 0)
    $toTimeSpan = [TimeSpan]::new(0, 0, 0)
    if ( ([TimeSpan]::TryParse($FromTime, [ref] $fromTimeSpan) -eq $false) )
    {
      throw "Parsing of the FromTime parameter failed. Try use format 00:00:00,000 or 00:00:00.000 with `".`" as delimiter at the end."
    }
    if ( ([TimeSpan]::TryParse($ToTime, [ref] $toTimeSpan) -eq $false) )
    {
      throw "Parsing of the FromTime parameter failed. Try use format 00:00:00,000 or 00:00:00.000 with `".`" as delimiter at the end."
    }
  }
  Process
  {
    $subtitlesShifted = New-Object 'System.Collections.Generic.List[Subtitle]'
    Write-Debug -Message "The temporary object start time: $($_.StartTime)"
    Write-Verbose -Message "Processing subtitle: $($_.Index)"
    $Subtitle | ForEach-Object `
    {
      if (($_.Index -ge $FromSubtitleIndex -and $_.Index -le $ToSubtitleIndex) -or ($_.StartTime -ge $fromTimeSpan -and $_.StartTime -le $toTimeSpan))
      {
        $subtitlesShifted.Add($Subtitle.ChangeDuration($timeSpan))
      }
    }
    Write-Debug -Message "The temporary object start time: $($_.StartTime)"
    Write-Output $subtitlesShifted
  }
  End
  {
    Write-Verbose -Message "The pipeline processed."

  }
}

function Write-Subtitle
{
  <#
      .SYNOPSIS
      Writes a subtitle or subtitles to a file.

      .DESCRIPTION
      This cmdlet writes a collection or a single subtitle file to the specified or the original file. The original file overwritten if no destination file is specified or if the specified path is same as original. If destination suffix is specified, a new subtitle file in original location and original name with suffix is created.

      .PARAMETER Subtitle
      Specifies the subtitle collection to adjust. Any collection which can be iterated is supported.

      .PARAMETER Path
      Specifies a destination path where the subtitle file with the original or a new name will be written.

      .PARAMETER NewFile
      Specifies a new file name for synchronized subtitles. The '*.srt' file extension is added automatically. Don't use this parameter with batch processing. All subtitles will be written into this, single file.

      .PARAMETER Suffix
      Specifies a desired destination file suffix name. Use this parameter with batch processing. All subtitles files names will be modified with this suffix.

      .PARAMETER DestinationFile
      Specifies a desired destination file name. The '*.srt' file extension is added automatically. Don't use this parameter with batch processing. All subtitles will be written into this, single file.

      .PARAMETER DestinationFileSuffix
      Specifies a desired destination file suffix name. Use this parameter with batch processing. All subtitles files names will be modified with this suffix.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to its original file in the original path.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Path C:\Temp
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to its original file in the new path C:\Temp.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -NewFile 'SomeMovieDVDVersion'
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the new file 'SomeMovieDVDVersion.srt' in the original path.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Suffix '-resync'
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the original path.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Path C:\Temp -DestinationFile 'SomeMovieDVDVersion'
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the new file 'SomeMovieDVDVersion.srt' in the new path C:\Temp.

      .EXAMPLE
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Path C:\Temp -DestinationFileSuffix '-resync'
      Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the new path C:\Temp.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to its original file in the original path.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Path C:\Temp
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to its original file name in the new path C:\Temp.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Suffix '-resync'
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the original path.

      .EXAMPLE
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | Read-Subtitle | Sync-Subtitle -TimeShift 5000 | Write-Subtitle -Path C:\Temp -DestinationFileSuffix '-resync'
      Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the new path C:\Temp.

      .NOTES
      - This cmdlet uses the OOP approach. The cmdlet use custom made class for the subtitle representation and as the output.
      - If you want synchronize multiple subtitles in batch, process files from one directory only.
      - A destination file name or a original file name suffix is supported as the output file name variations.

      .LINK
      https://github.com/KUTlime/PowerShell-Subtitle-Module

      .INPUTS
      Subtitle
      Subtitle[]

      .OUTPUTS
      This cmdlet produces no output to the output stream, only creates/change files on the file storage.
  #>


  [CmdletBinding(
    PositionalBinding = $false,
    HelpUri = 'https://github.com/KUTlime/PowerShell-Subtitle-Module'
  )]
  [Alias('wsub', 'writesub', 'ws', 'Set-Subtitle')]
  [OutputType([void])]
  param
  (
    # A collection of subtitles to synchronize.
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitleOnly',
      Position = 0)]
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePath',
      Position = 0)]
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitleNewName',
      Position = 0)]
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitleSuffix',
      Position = 0)]
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePathDestinationFile',
      Position = 0)]
    [Parameter(
      Mandatory = $true,
      ValueFromPipeline = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePathDestinationNameSuffix',
      Position = 0)]
    [ValidateNotNull()]
    [ValidateScript( {
        if ( ($_.Count -eq 0) )
        {
          throw "The subtitle collection is empty"
        }
        return $true
      })]
    [Object[]]
    $Subtitle,

    # A path to subtitle file of folder where the subtitles are located.
    [Parameter(Mandatory = $true,
      ValueFromPipeline = $false,
      ValueFromPipelineByPropertyName = $false,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePath',
      Position = 1)]
    [Parameter(
      ParameterSetName = 'SubtitlePathDestinationFile',
      Mandatory = $true
    )]
    [Parameter(
      ParameterSetName = 'SubtitlePathDestinationNameSuffix',
      Mandatory = $true
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {
        if ( -Not ($_ | Test-Path) )
        {
          throw "File or folder does not exist"
        }
        return $true
      })]
    [System.IO.FileInfo]
    $Path,

    # A name of the new file name.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitleNewName',
      Position = 2)]
    [ValidateNotNullOrEmpty()]
    [String]
    $NewFile,

    # A suffix for the destination file. Use this for batch processing. The original file name will be used with suffix.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitleSuffix',
      Position = 3)]
    [ValidateNotNullOrEmpty()]
    [String]
    $Suffix,

    # A name of destination file to avoid binding problems when pipeline is used.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePathDestinationFile',
      Position = 4)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DestinationFile,

    # A name of destination file suffix to avoid binding problems when pipeline is used.
    [Parameter(
      Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      ValueFromRemainingArguments = $false,
      ParameterSetName = 'SubtitlePathDestinationNameSuffix',
      Position = 5)]
    [ValidateNotNullOrEmpty()]
    [String]
    $DestinationFileSuffix
  )

  Begin
  {
  }
  Process
  {
    switch ($PsCmdlet.ParameterSetName)
    {
      "SubtitleOnly"
      {
        $filePath = $Subtitle[0].Path.Directory.FullName + "\" + $Subtitle[0].Path.Name
      }
      "SubtitlePath"
      {
        $filePath = $Path.FullName + "\" + $Subtitle[0].Path.Name
      }
      "SubtitleNewName"
      {
        $filePath = $Subtitle[0].Path.Directory.FullName + "\" + $NewFile + '.srt'
      }
      "SubtitleSuffix"
      {
        $filePath = $Subtitle[0].Path.Directory.FullName + "\" + [IO.Path]::GetFileNameWithoutExtension($Subtitle[0].Path) + $Suffix + '.srt'
      }
      "SubtitlePathDestinationFile"
      {
        $filePath = $Path.FullName + "\" + $DestinationFile + '.srt'
      }
      "SubtitlePathDestinationNameSuffix"
      {
        $filePath = $Path.FullName + "\" + [IO.Path]::GetFileNameWithoutExtension($Subtitle[0].Path) + $DestinationFileSuffix + '.srt'
      }
    }

    $stringBuilder = [System.Text.StringBuilder]::new(200000)

    $Subtitle | ForEach-Object { $stringBuilder.Append($_.ToString()) | Out-Null }

    $stringBuilder.ToString() | Out-File -FilePath ($filePath + '_') -Encoding:unicode -Append -Force
  }
  End
  {
    Write-Verbose -Message "The pipeline processed."
    Write-Verbose -Message $filePath
    Get-ChildItem -Path ([IO.Path]::GetDirectoryName($filePath)) -Filter '*.srt_' |
      ForEach-Object `
      {
        $NewName = $_.Name -replace '.srt_', '.srt'
        $Destination = Join-Path -Path $_.Directory.FullName -ChildPath $NewName
        Move-Item -Path $_.FullName -Destination $Destination -Force
      }
  }
}