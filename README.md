# PowerShell Subtitle Module
A PowerShell module to handle subtitles operations.

# Introduction
This module gives PowerShell an easy, intuitive and powerful capability to handle subtitle synchronization.

# Main feature
* The module can read, sync and write subtitles to file/files.
* Synchronization based on time or subtitle index.
* Synchronization of particular subtitle interval based on subtitle index or time.
* Batch synchronization.
* OOP and pipeline oriented.

# Basic use
```powershell
Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
Sync-Subtitle -TimeShift 5000 | 
Write-Subtitle
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to its original file in the original path.

```powershell
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Path C:\Temp
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to its original file in the new path C:\Temp.

```powershell
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -NewFile 'SomeMovieDVDVersion'
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the new file 'SomeMovieDVDVersion.srt' in the original path.

```powershell
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Suffix '-resync'
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the original path.

```powershell
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Path C:\Temp -DestinationFile 'SomeMovieDVDVersion'
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the new file 'SomeMovieDVDVersion.srt' in the new path C:\Temp.

```powershell
      Read-Subtitle -Path 'C:\MyMovies\SomeMovie\SomeMovie.srt' | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Path C:\Temp -DestinationFileSuffix '-resync'
```
Reads subtitles from the file SomeMovie.srt located in C:\MyMovies\SomeMovie\ path and delays all subtitles by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the new path C:\Temp.

```powershell
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | 
      Read-Subtitle | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle
```
Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to its original file in the original path.

```powershell
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | 
      Read-Subtitle | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Path C:\Temp
```
Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to its original file name in the new path C:\Temp.

```powershell
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | 
      Read-Subtitle | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Suffix '-resync'
```
Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the original path.

```powershell
      Get-ChildItem -Path C:\MyMovies\SomeTVShow\SeasonOne -Filter '*.srt' | 
      Read-Subtitle | 
      Sync-Subtitle -TimeShift 5000 | 
      Write-Subtitle -Path C:\Temp -DestinationFileSuffix '-resync'
```
Reads all srt files located in C:\MyMovies\SomeTVShow\SeasonOne path one by one. All subtitles are delayed by 5 seconds. The result is written to the original file name modified by '-resync' suffix in the new path C:\Temp.


# Subtitle class
Represents a subtitle and its properties.
## Constructors
### Subtitle(string inputText)
Only provided constructor. It extracts and transform the necessary information from raw string into subtitle instance.

## Properties
### Index
Gets or sets a subtitle index. UInt32 is used to store the value.
### StartTime
Gets or sets a subtitle start time. The .NET TimeSpan structure is used to store the value.
### EndTime
Gets or sets a subtitle end time. The .NET TimeSpan structure is used to store the value.
### Text
Gets or sets a subtitle text. The .NET string is used to store the value.
### Path
Gets or sets the original file path from which the subtitle is extracted. The .NET System.IO.FileInfo is used to store the value.
## Methods
### Subtitle ChangeDuration(TimeSpan timespan)
Adjusts the start and end time with the input timespan.
### string ToString()
Converts the subtitle of this instance to its equivalent string representation.

# Notes
* Use batch processing with files from one directory at once. It is not a bug, it is a well planned feature.
* Use **Suffix** and **DestinationFileSuffix** when batch processing multiple files from one folder.

# FAQ
## Why the minimal PowerShell version is 5.1.0.0?
The module uses OOP approach. All cmdlets use a custom class called **Subtitle**. Classes is supported in PS 5.x.x.x version and module was tested only on version 5.1.0.x.

## Why there are NewFile and DestinationFile parameters? 
PS adopts the parameter set concept (*see links*). Each parameter set must have an unique parameter. The parameters NewFile and DestinationFile (*also Suffix and DestinationFileSuffix*) are necessary to provide rich functionality to module users.

## Why no batch processing with multiple different directories?
All synchronized subtitles are written into temporary file with '\*.srt_' extension. At the end of pipeline processing, all '\*.srt_' files from the submitted or the original path are renamed to '\*.srt' files and the original file names are overwritten if present. The is no easy, clean and nice way how to store original different paths. Brutal force approach to search through all drives was dropped and another approach is planned in future version of this module.

# Planned features
* Conversion between sub <-> srt file format.
* Automatic fix of subtitle merge when no emply line is present between subtitles.
* Solve the problem with multiple folder synchronization.
* Some simple GUI on top of the module cmdlets.

# Links
[The PowerShell Subtitle Module at PowerShell Gallery](https://www.powershellgallery.com/packages/Subtitle/)
[Parameter set cannot be resolved using the specified named parameters](https://stackoverflow.com/questions/18144016/powershell-parameter-set-cannot-be-resolved-using-the-specified-named-parameter)