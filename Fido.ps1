#
# Fido v1.51 - Feature ISO Downloader, for retail Windows images and UEFI Shell
# Copyright © 2019-2023 Pete Batard <pete@akeo.ie>
# Command line support: Copyright © 2021 flx5
# ConvertTo-ImageSource: Copyright © 2016 Chris Carter
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# NB: You must have a BOM on your .ps1 if you want Powershell to actually
# realise it should use Unicode for the UI rather than ISO-8859-1.

#region Parameters
param(
	# (Optional) The title to display on the application window.
	[string]$AppTitle = "Fido - Feature ISO Downloader",
	# (Optional) '|' separated UI localization strings.
	[string]$LocData,
	# (Optional) Forced locale
	[string]$Locale = "en-US",
	# (Optional) Path to a file that should be used for the UI icon.
	[string]$Icon,
	# (Optional) Name of a pipe the download URL should be sent to.
	# If not provided, a browser window is opened instead.
	[string]$PipeName,
	# (Optional) Specify Windows version (e.g. "Windows 10") [Toggles commandline mode]
	[string]$Win,
	# (Optional) Specify Windows release (e.g. "21H1") [Toggles commandline mode]
	[string]$Rel,
	# (Optional) Specify Windows edition (e.g. "Pro") [Toggles commandline mode]
	[string]$Ed,
	# (Optional) Specify Windows language [Toggles commandline mode]
	[string]$Lang,
	# (Optional) Specify Windows architecture [Toggles commandline mode]
	[string]$Arch,
	# (Optional) Only display the download URL [Toggles commandline mode]
	[switch]$GetUrl = $false,
	# (Optional) Increase verbosity
	[switch]$Verbose = $false
)
#endregion

try {
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$Cmd = $false
if ($Win -or $Rel -or $Ed -or $Lang -or $Arch -or $GetUrl) {
	$Cmd = $true
}

# Return a decimal Windows version that we can then check for platform support.
# Note that because we don't want to have to support this script on anything
# other than Windows, this call returns 0.0 for PowerShell running on Linux/Mac.
function Get-Platform-Version()
{
	$version = 0.0
	$platform = [string][System.Environment]::OSVersion.Platform
	# This will filter out non Windows platforms
	if ($platform.StartsWith("Win")) {
		# Craft a decimal numeric version of Windows
		$version = [System.Environment]::OSVersion.Version.Major * 1.0 + [System.Environment]::OSVersion.Version.Minor * 0.1
	}
	return $version
}

$winver = Get-Platform-Version

# The default TLS for Windows 8.x doesn't work with Microsoft's servers so we must force it
if ($winver -lt 10.0) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12
}

#region Assembly Types
$Drawing_Assembly = "System.Drawing"
# PowerShell 7 altered the name of the Drawing assembly...
if ($host.version -ge "7.0") {
	$Drawing_Assembly += ".Common"
}

$Signature = @{
	Namespace            = "WinAPI"
	Name                 = "Utils"
	Language             = "CSharp"
	UsingNamespace       = "System.Runtime", "System.IO", "System.Text", "System.Drawing", "System.Globalization"
	ReferencedAssemblies = $Drawing_Assembly
	ErrorAction          = "Stop"
	WarningAction        = "Ignore"
	IgnoreWarnings       = $true
	MemberDefinition     = @"
		[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
		internal static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);

		[DllImport("user32.dll")]
		public static extern bool ShowWindow(IntPtr handle, int state);
		// Extract an icon from a DLL
		public static Icon ExtractIcon(string file, int number, bool largeIcon) {
			IntPtr large, small;
			ExtractIconEx(file, number, out large, out small, 1);
			try {
				return Icon.FromHandle(largeIcon ? large : small);
			} catch {
				return null;
			}
		}
"@
}

if (!$Cmd) {
	Write-Host Please Wait...

	if (!("WinAPI.Utils" -as [type]))
	{
		Add-Type @Signature
	}
	Add-Type -AssemblyName PresentationFramework

	# Hide the powershell window: https://stackoverflow.com/a/27992426/1069307
	[WinAPI.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0) | Out-Null
}
#endregion

#region Data
$zh = 0x10000
$ko = 0x20000
$WindowsVersions = @(
	@(
		@("Windows 11", "windows11"),
		@(
			"22H2 v2 (Build 22621.1702 - 2023.05)",
			@("Windows 11 Home/Pro/Edu", 2616),
			@("Windows 11 Home China ", ($zh + 2617))
		)
	),
	@(
		@("Windows 10", "Windows10ISO"),
		@(
			"22H2 v1 (Build 19045.2965 - 2023.05)",
			@("Windows 10 Home/Pro/Edu", 2618),
			@("Windows 10 Home China ", ($zh + 2378))
		)
	)
	@(
		@("Windows 8.1", "windows8ISO"),
		@(
			"Update 3 (build 9600)",
			@("Windows 8.1 Standard", 52),
			@("Windows 8.1 N", 55)
			@("Windows 8.1 Single Language", 48),
			@("Windows 8.1 K", ($ko + 61)),
			@("Windows 8.1 KN", ($ko + 62))
		)
	),
	@(
		@("UEFI Shell 2.2", "UEFI_SHELL 2.2"),
		@(
			"23H1 (edk2-stable202305)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"22H2 (edk2-stable202211)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"22H1 (edk2-stable202205)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"21H2 (edk2-stable202108)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"21H1 (edk2-stable202105)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"20H2 (edk2-stable202011)",
			@("Release", 0),
			@("Debug", 1)
		)
	),
	@(
		@("UEFI Shell 2.0", "UEFI_SHELL 2.0"),
		@(
			"4.632 [20100426]",
			@("Release", 0)
		)
	)
)
#endregion

#region Functions
function Select-Language([string]$LangName)
{
	# Use the system locale to try select the most appropriate language
	[string]$SysLocale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
	if (($SysLocale.StartsWith("ar") -and $LangName -like "*Arabic*") -or `
		($SysLocale -eq "pt-BR" -and $LangName -like "*Brazil*") -or `
		($SysLocale.StartsWith("ar") -and $LangName -like "*Bulgar*") -or `
		($SysLocale -eq "zh-CN" -and $LangName -like "*Chinese*" -and $LangName -like "*simp*") -or `
		($SysLocale -eq "zh-TW" -and $LangName -like "*Chinese*" -and $LangName -like "*trad*") -or `
		($SysLocale.StartsWith("hr") -and $LangName -like "*Croat*") -or `
		($SysLocale.StartsWith("cz") -and $LangName -like "*Czech*") -or `
		($SysLocale.StartsWith("da") -and $LangName -like "*Danish*") -or `
		($SysLocale.StartsWith("nl") -and $LangName -like "*Dutch*") -or `
		($SysLocale -eq "en-US" -and $LangName -eq "English") -or `
		($SysLocale.StartsWith("en") -and $LangName -like "*English*" -and ($LangName -like "*inter*" -or $LangName -like "*ingdom*")) -or `
		($SysLocale.StartsWith("et") -and $LangName -like "*Eston*") -or `
		($SysLocale.StartsWith("fi") -and $LangName -like "*Finn*") -or `
		($SysLocale -eq "fr-CA" -and $LangName -like "*French*" -and $LangName -like "*Canad*") -or `
		($SysLocale.StartsWith("fr") -and $LangName -eq "French") -or `
		($SysLocale.StartsWith("de") -and $LangName -like "*German*") -or `
		($SysLocale.StartsWith("el") -and $LangName -like "*Greek*") -or `
		($SysLocale.StartsWith("he") -and $LangName -like "*Hebrew*") -or `
		($SysLocale.StartsWith("hu") -and $LangName -like "*Hungar*") -or `
		($SysLocale.StartsWith("id") -and $LangName -like "*Indones*") -or `
		($SysLocale.StartsWith("it") -and $LangName -like "*Italia*") -or `
		($SysLocale.StartsWith("ja") -and $LangName -like "*Japan*") -or `
		($SysLocale.StartsWith("ko") -and $LangName -like "*Korea*") -or `
		($SysLocale.StartsWith("lv") -and $LangName -like "*Latvia*") -or `
		($SysLocale.StartsWith("lt") -and $LangName -like "*Lithuania*") -or `
		($SysLocale.StartsWith("ms") -and $LangName -like "*Malay*") -or `
		($SysLocale.StartsWith("nb") -and $LangName -like "*Norw*") -or `
		($SysLocale.StartsWith("fa") -and $LangName -like "*Persia*") -or `
		($SysLocale.StartsWith("pl") -and $LangName -like "*Polish*") -or `
		($SysLocale -eq "pt-PT" -and $LangName -eq "Portuguese") -or `
		($SysLocale.StartsWith("ro") -and $LangName -like "*Romania*") -or `
		($SysLocale.StartsWith("ru") -and $LangName -like "*Russia*") -or `
		($SysLocale.StartsWith("sr") -and $LangName -like "*Serbia*") -or `
		($SysLocale.StartsWith("sk") -and $LangName -like "*Slovak*") -or `
		($SysLocale.StartsWith("sl") -and $LangName -like "*Slovenia*") -or `
		($SysLocale -eq "es-ES" -and $LangName -eq "Spanish") -or `
		($SysLocale.StartsWith("es") -and $Locale -ne "es-ES" -and $LangName -like "*Spanish*") -or `
		($SysLocale.StartsWith("sv") -and $LangName -like "*Swed*") -or `
		($SysLocale.StartsWith("th") -and $LangName -like "*Thai*") -or `
		($SysLocale.StartsWith("tr") -and $LangName -like "*Turk*") -or `
		($SysLocale.StartsWith("uk") -and $LangName -like "*Ukrain*") -or `
		($SysLocale.StartsWith("vi") -and $LangName -like "*Vietnam*")) {
		return $true
	}
	return $false
}

function Add-Entry([int]$pos, [string]$Name, [array]$Items, [string]$DisplayName)
{
	$Title = New-Object System.Windows.Controls.TextBlock
	$Title.FontSize = $WindowsVersionTitle.FontSize
	$Title.Height = $WindowsVersionTitle.Height;
	$Title.Width = $WindowsVersionTitle.Width;
	$Title.HorizontalAlignment = "Left"
	$Title.VerticalAlignment = "Top"
	$Margin = $WindowsVersionTitle.Margin
	$Margin.Top += $pos * $dh
	$Title.Margin = $Margin
	$Title.Text = Get-Translation($Name)
	$XMLGrid.Children.Insert(2 * $Stage + 2, $Title)

	$Combo = New-Object System.Windows.Controls.ComboBox
	$Combo.FontSize = $WindowsVersion.FontSize
	$Combo.Height = $WindowsVersion.Height;
	$Combo.Width = $WindowsVersion.Width;
	$Combo.HorizontalAlignment = "Left"
	$Combo.VerticalAlignment = "Top"
	$Margin = $WindowsVersion.Margin
	$Margin.Top += $pos * $script:dh
	$Combo.Margin = $Margin
	$Combo.SelectedIndex = 0
	if ($Items) {
		$Combo.ItemsSource = $Items
		if ($DisplayName) {
			$Combo.DisplayMemberPath = $DisplayName
		} else {
			$Combo.DisplayMemberPath = $Name
		}
	}
	$XMLGrid.Children.Insert(2 * $Stage + 3, $Combo)

	$XMLForm.Height += $dh;
	$Margin = $Continue.Margin
	$Margin.Top += $dh
	$Continue.Margin = $Margin
	$Margin = $Back.Margin
	$Margin.Top += $dh
	$Back.Margin = $Margin

	return $Combo
}

function Refresh-Control([object]$Control)
{
	$Control.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Continue.UpdateLayout() }, $null, $null) | Out-Null
}

function Send-Message([string]$PipeName, [string]$Message)
{
	[System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
	$Pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList ".", $PipeName, ([System.IO.Pipes.PipeDirection]::Out), ([System.IO.Pipes.PipeOptions]::None), ([System.Security.Principal.TokenImpersonationLevel]::Impersonation)
	try {
		$Pipe.Connect(1000)
	} catch {
		Write-Host $_.Exception.Message
	}
	$bRequest = $Encoding.GetBytes($Message)
	$cbRequest = $bRequest.Length;
	$Pipe.Write($bRequest, 0, $cbRequest);
	$Pipe.Dispose()
}

# From https://www.powershellgallery.com/packages/IconForGUI/1.5.2
# Copyright © 2016 Chris Carter. All rights reserved.
# License: https://creativecommons.org/licenses/by-sa/4.0/
function ConvertTo-ImageSource
{
	[CmdletBinding()]
	Param(
		[Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[System.Drawing.Icon]$Icon
	)

	Process {
		foreach ($i in $Icon) {
			[System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon(
				$i.Handle,
				(New-Object System.Windows.Int32Rect -Args 0,0,$i.Width, $i.Height),
				[System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions()
			)
		}
	}
}

function Throw-Error([object]$Req, [string]$Alt)
{
	$Err = $(GetElementById -Request $Req -Id "errorModalMessage").innerText -replace "<[^>]+>" -replace "\s+", " "
	if (!$Err) {
		$Err = $Alt
	} else {
		$Err = [System.Text.Encoding]::UTF8.GetString([byte[]][char[]]$Err)
	}
	throw $Err
}

# Translate a message string
function Get-Translation([string]$Text)
{
	if (!($English -contains $Text)) {
		Write-Host "Error: '$Text' is not a translatable string"
		return "(Untranslated)"
	}
	if ($Localized) {
		if ($Localized.Length -ne $English.Length) {
			Write-Host "Error: '$Text' is not a translatable string"
		}
		for ($i = 0; $i -lt $English.Length; $i++) {
			if ($English[$i] -eq $Text) {
				if ($Localized[$i]) {
					return $Localized[$i]
				} else {
					return $Text
				}
			}
		}
	}
	return $Text
}

# Some PowerShells don't have Microsoft.mshtml assembly (comes with MS Office?)
# so we can't use ParsedHtml or IHTMLDocument[2|3] features there...
function GetElementById([object]$Request, [string]$Id)
{
	try {
		return $Request.ParsedHtml.IHTMLDocument3_GetElementByID($Id)
	} catch {
		return $Request.AllElements | ? {$_.id -eq $Id}
	}
}

function Error([string]$ErrorMessage)
{
	Write-Host Error: $ErrorMessage
	if (!$Cmd) {
		$XMLForm.Title = $(Get-Translation("Error")) + ": " + $ErrorMessage
		Refresh-Control($XMLForm)
		$XMLGrid.Children[2 * $script:Stage + 1].IsEnabled = $true
		$UserInput = [System.Windows.MessageBox]::Show($XMLForm.Title,  $(Get-Translation("Error")), "OK", "Error")
		$script:ExitCode = $script:Stage--
	} else {
		$script:ExitCode = 2
	}
}

function Get-RandomDate()
{
	[DateTime]$Min = "1/1/2008"
	[DateTime]$Max = [DateTime]::Now

	$RandomGen = new-object random
	$RandomTicks = [Convert]::ToInt64( ($Max.ticks * 1.0 - $Min.Ticks * 1.0 ) * $RandomGen.NextDouble() + $Min.Ticks * 1.0 )
	$Date = new-object DateTime($RandomTicks)
	return $Date.ToString("yyyyMMdd")
}
#endregion

#region Form
[xml]$XAML = @"
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Height = "162" Width = "384" ResizeMode = "NoResize">
	<Grid Name = "XMLGrid">
		<Button Name = "Continue" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
		<Button Name = "Back" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "194,78,0,0"/>
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
		<CheckBox Name = "Check" FontSize = "14" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,0,0,0" Visibility="Collapsed" />
	</Grid>
</Window>
"@
#endregion

#region Globals
$ErrorActionPreference = "Stop"
$dh = 58
$Stage = 0
$SelectedIndex = 0
$ltrm = "‎"
if ($Cmd) {
	$ltrm = ""
}
$MaxStage = 4
$SessionId = [guid]::NewGuid()
$ExitCode = 100
$Locale = $Locale
$RequestData = @{}
# This GUID applies to all visitors, regardless of their locale
$RequestData["GetLangs"] = @("a8f8f489-4c7f-463a-9ca6-5cff94d8d041", "getskuinformationbyproductedition" )
# This GUID applies to visitors of the en-US download page. Other locales may get a different GUID.
$RequestData["GetLinks"] = @("6e2a1789-ef16-4f27-a296-74ef7ef5d96b", "GetProductDownloadLinksBySku" )
# Create a semi-random Linux User-Agent string
$FirefoxVersion = Get-Random -Minimum 90 -Maximum 110
$FirefoxDate = Get-RandomDate
$UserAgent = "Mozilla/5.0 (X11; Linux i586; rv:$FirefoxVersion.0) Gecko/$FirefoxDate Firefox/$FirefoxVersion.0"
$Verbosity = 2
if ($Cmd) {
	if ($GetUrl) {
		$Verbosity = 0
	} elseif (!$Verbose) {
		$Verbosity = 1
	}
}
#endregion

# Localization
$EnglishMessages = "en-US|Version|Release|Edition|Language|Architecture|Download|Continue|Back|Close|Cancel|Error|Please wait...|" +
	"Download using a browser|Download of Windows ISOs is unavailable due to Microsoft having altered their website to prevent it.|" +
	"PowerShell 3.0 or later is required to run this script.|Do you want to go online and download it?|" +
	"This feature is not available on this platform."
[string[]]$English = $EnglishMessages.Split('|')
[string[]]$Localized = $null
if ($LocData -and !$LocData.StartsWith("en-US")) {
	$Localized = $LocData.Split('|')
	# Adjust the $Localized array if we have more or fewer strings than in $EnglishMessages
	if ($Localized.Length -lt $English.Length) {
		while ($Localized.Length -ne $English.Length) {
			$Localized += $English[$Localized.Length]
		}
	} elseif ($Localized.Length -gt $English.Length) {
		$Localized = $LocData.Split('|')[0..($English.Length - 1)]
	}
	$Locale = $Localized[0]
}
$QueryLocale = $Locale

# Convert a size in bytes to a human readable string
function Size-To-Human-Readable([uint64]$size)
{
	$suffix = "bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
	$i = 0
	while ($size -gt 1kb) {
		$size = $size / 1kb
		$i++
	}
	"{0:N1} {1}" -f $size, $suffix[$i]
}

# Check if the locale we want is available - Fall back to en-US otherwise
function Check-Locale
{
	try {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/"
		if ($Verbosity -ge 2) {
			Write-Host Querying $url
		}
		Invoke-WebRequest -UseBasicParsing -MaximumRedirection 0 -UserAgent $UserAgent $url | Out-Null
	} catch {
		$script:QueryLocale = "en-US"
	}
}

# Return an array of releases (e.g. 20H2, 21H1, ...) for the selected Windows version
function Get-Windows-Releases([int]$SelectedVersion)
{
	$i = 0
	$releases = @()
	foreach ($version in $WindowsVersions[$SelectedVersion]) {
		if (($i -ne 0) -and ($version -is [array])) {
			$releases += @(New-Object PsObject -Property @{ Release = $ltrm + $version[0].Replace(")", ")" + $ltrm); Index = $i })
		}
		$i++
	}
	return $releases
}

# Return an array of editions (e.g. Home, Pro, etc) for the selected Windows release
function Get-Windows-Editions([int]$SelectedVersion, [int]$SelectedRelease)
{
	$editions = @()
	foreach ($release in $WindowsVersions[$SelectedVersion][$SelectedRelease])
	{
		if ($release -is [array]) {
			if (($release[1] -lt 0x10000) -or ($Locale.StartsWith("ko") -and ($release[1] -band $ko)) -or ($Locale.StartsWith("zh") -and ($release[1] -band $zh))) {
				$editions += @(New-Object PsObject -Property @{ Edition = $release[0]; Id = $($release[1] -band 0xFFFF) })
			}
		}
	}
	return $editions
}

# Return an array of languages for the selected edition
function Get-Windows-Languages([int]$SelectedVersion, [int]$SelectedEdition)
{
	$languages = @()
	$i = 0;
	if ($WindowsVersions[$SelectedVersion][0][1] -eq "WIN7") {
		foreach ($entry in $Windows7Versions[$SelectedEdition]) {
			if ($entry[0] -ne "") {
				$languages += @(New-Object PsObject -Property @{ DisplayLanguage = $entry[0]; Language = $entry[1]; Id = $i })
			}
			$i++
		}
	} elseif ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
		$languages += @(New-Object PsObject -Property @{ DisplayLanguage = "English (US)"; Language = "en-us"; Id = 0 })
	} else {
		# Microsoft download protection now requires the sessionId to be whitelisted through vlscppe.microsoft.com/tags
		$url = "https://vlscppe.microsoft.com/tags?org_id=y6jn8c31&session_id=" + $SessionId
		if ($Verbosity -ge 2) {
			Write-Host Querying $url
		}
		try {
			Invoke-WebRequest -UseBasicParsing -MaximumRedirection 0 -UserAgent $UserAgent $url | Out-Null
		} catch {
			Error($_.Exception.Message)
			return @()
		}
		$url = "https://www.microsoft.com/" + $QueryLocale + "/api/controls/contentinclude/html"
		$url += "?pageId=" + $RequestData["GetLangs"][0]
		$url += "&host=www.microsoft.com"
		$url += "&segments=software-download," + $WindowsVersions[$SelectedVersion][0][1]
		$url += "&query=&action=" + $RequestData["GetLangs"][1]
		$url += "&sessionId=" + $SessionId
		$url += "&productEditionId=" + [Math]::Abs($SelectedEdition)
		$url += "&sdVersion=2"
		if ($Verbosity -ge 2) {
			Write-Host Querying $url
		}

		$script:SelectedIndex = 0
		try {
			$r = Invoke-WebRequest -Method Post -UseBasicParsing -UserAgent $UserAgent -SessionVariable "Session" $url
			if ($r -match "errorModalMessage") {
				Throw-Error -Req $r -Alt "Could not retrieve languages from server"
			}
			$r = $r -replace "`n" -replace "`r"
			$pattern = '.*<select id="product-languages"[^>]*>(.*)</select>.*'
			$html = [regex]::Match($r, $pattern).Groups[1].Value
			# Go through an XML conversion to keep all PowerShells happy...
			$html = $html.Replace("selected value", "value")
			$html = "<options>" + $html + "</options>"
			$xml = [xml]$html
			foreach ($var in $xml.options.option) {
				$json = $var.value | ConvertFrom-Json;
				if ($json) {
					$languages += @(New-Object PsObject -Property @{ DisplayLanguage = $var.InnerText; Language = $json.language; Id = $json.id })
					if (Select-Language($json.language)) {
						$script:SelectedIndex = $i
					}
					$i++
				}
			}
			if ($languages.Length -eq 0) {
				Throw-Error -Req $r -Alt "Could not parse languages"
			}
		} catch {
			Error($_.Exception.Message)
			return @()
		}
	}
	return $languages
}

# Return an array of download links for each supported arch
function Get-Windows-Download-Links([int]$SelectedVersion, [int]$SelectedRelease, [int]$SelectedEdition, [string]$SkuId, [string]$LanguageName)
{
	$links = @()
	if ($WindowsVersions[$SelectedVersion][0][1] -eq "WIN7") {
		foreach ($Version in $Windows7Versions[$SelectedEdition][$SkuId][2]) {
			$links += @(New-Object PsObject -Property @{ Type = $Version[0]; Link = $Version[1] })
		}
	} elseif ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
		$tag = $WindowsVersions[$SelectedVersion][$SelectedRelease][0].Split(' ')[0]
		$shell_version = $WindowsVersions[$SelectedVersion][0][1].Split(' ')[1]
		$url = "https://github.com/pbatard/UEFI-Shell/releases/download/" + $tag
		$link = $url + "/UEFI-Shell-" + $shell_version + "-" + $tag
		if ($SelectedEdition -eq 0) {
			$link += "-RELEASE.iso"
		} else {
			$link += "-DEBUG.iso"
		}
		try {
			# Read the supported archs from the release URL
			$url += "/Version.xml"
			$xml = New-Object System.Xml.XmlDocument
			if ($Verbosity -ge 2) {
				Write-Host Querying $url
			}
			$xml.Load($url)
			$sep = ""
			$archs = ""
			foreach($arch in $xml.release.supported_archs.arch) {
				$archs += $sep + $arch
				$sep = ", "
			}
			$links += @(New-Object PsObject -Property @{ Type = $archs; Link = $link })
		} catch {
			Error($_.Exception.Message)
			return @()
		}
	} else {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/api/controls/contentinclude/html"
		$url += "?pageId=" + $RequestData["GetLinks"][0]
		$url += "&host=www.microsoft.com"
		$url += "&segments=software-download," + $WindowsVersions[$SelectedVersion][0][1]
		$url += "&query=&action=" + $RequestData["GetLinks"][1]
		$url += "&sessionId=" + $SessionId
		$url += "&skuId=" + $SkuId
		$url += "&language=" + $LanguageName
		$url += "&sdVersion=2"
		if ($Verbosity -ge 2) {
			Write-Host Querying $url
		}

		$i = 0
		$script:SelectedIndex = 0

		try {
			$Is64 = [Environment]::Is64BitOperatingSystem
			# Must add a referer for this request, else Microsoft's servers will deny it
			$ref = "https://www.microsoft.com/software-download/windows11"
			$r = Invoke-WebRequest -Method Post -Headers @{ "Referer" = $ref } -UseBasicParsing -UserAgent $UserAgent -WebSession $Session $url
			if ($r -match "errorModalMessage") {
				$Alt = [regex]::Match($r.Content, '<p id="errorModalMessage">(.+?)<\/p>').Groups[1].Value -replace "<[^>]+>" -replace "\s+", " " -replace "\?\?\?", "-"
				$Alt = [System.Text.Encoding]::UTF8.GetString([byte[]][char[]]$Alt)
				if (!$Alt) {
					$Alt = "Could not retrieve architectures from server"
				} elseif ($Alt -match "715-123130") {
					$Alt += " " + $SessionId + "."
				}
				Throw-Error -Req $r -Alt $Alt
			}
			$pattern = '(?s)(<input.*?></input>)'
			ForEach-Object { [regex]::Matches($r, $pattern) } | ForEach-Object { $html += $_.Groups[1].value }
			# Need to fix the HTML and JSON data so that it is well-formed
			$html = $html.Replace("class=product-download-hidden", "")
			$html = $html.Replace("type=hidden", "")
			$html = $html.Replace("&nbsp;", " ")
			$html = $html.Replace("IsoX86", "&quot;x86&quot;")
			$html = $html.Replace("IsoX64", "&quot;x64&quot;")
			$html = "<inputs>" + $html + "</inputs>"
			$xml = [xml]$html
			foreach ($var in $xml.inputs.input) {
				$json = $var.value | ConvertFrom-Json;
				if ($json) {
					if (($Is64 -and $json.DownloadType -eq "x64") -or (!$Is64 -and $json.DownloadType -eq "x86")) {
						$script:SelectedIndex = $i
					}
					$links += @(New-Object PsObject -Property @{ Type = $json.DownloadType; Link = $json.Uri })
					$i++
				}
			}
			if ($links.Length -eq 0) {
				Throw-Error -Req $r -Alt "Could not retrieve ISO download links"
			}
		} catch {
			Error($_.Exception.Message)
			return @()
		}
	}
	return $links
}

# Process the download URL by either sending it through the pipe or by opening the browser
function Process-Download-Link([string]$Url)
{
	try {
		if ($PipeName -and !$Check.IsChecked) {
			Send-Message -PipeName $PipeName -Message $Url
		} else {
			if ($Cmd) {
				$pattern = '.*\/(.*\.iso).*'
				$File = [regex]::Match($Url, $pattern).Groups[1].Value
				# PowerShell implicit conversions are iffy, so we need to force them...
				$str_size = (Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Head).Headers.'Content-Length'
				$tmp_size = [uint64]::Parse($str_size)
				$Size = Size-To-Human-Readable $tmp_size
				Write-Host "Downloading '$File' ($Size)..."
				Start-BitsTransfer -Source $Url -Destination $File
			} else {
				Write-Host Download Link: $Url
				Start-Process -FilePath $Url
			}
		}
	} catch {
		Error($_.Exception.Message)
		return 404
	}
	return 0
}

if ($Cmd) {
	$winVersionId = $null
	$winReleaseId = $null
	$winEditionId = $null
	$winLanguageId = $null
	$winLanguageName = $null
	$winLink = $null

	# Windows 7 and non Windows platforms are too much of a liability
	if ($winver -le 6.1) {
		Error(Get-Translation("This feature is not available on this platform."))
		exit 403
	}

	$i = 0
	$Selected = ""
	if ($Win -eq "List") {
		Write-Host "Please select a Windows Version (-Win):"
	}
	foreach($version in $WindowsVersions) {
		if ($Win -eq "List") {
			Write-Host " -" $version[0][0]
		} elseif ($version[0][0] -match $Win) {
			$Selected += $version[0][0]
			$winVersionId = $i
			break;
		}
		$i++
	}
	if ($winVersionId -eq $null) {
		if ($Win -ne "List") {
			Write-Host "Invalid Windows version provided."
			Write-Host "Use '-Win List' for a list of available Windows versions."
		}
		exit 1
	}

	# Windows Version selection
	$releases = Get-Windows-Releases $winVersionId
	if ($Rel -eq "List") {
		Write-Host "Please select a Windows Release (-Rel) for ${Selected} (or use 'Latest' for most recent):"
	}
	foreach ($release in $releases) {
		if ($Rel -eq "List") {
			Write-Host " -" $release.Release
		} elseif (!$Rel -or $release.Release.StartsWith($Rel) -or $Rel -eq "Latest") {
			if (!$Rel -and $Verbosity -ge 1) {
				Write-Host "No release specified (-Rel). Defaulting to '$($release.Release)'."
			}
			$Selected += " " + $release.Release
			$winReleaseId = $release.Index
			break;
		}
	}
	if ($winReleaseId -eq $null) {
		if ($Rel -ne "List") {
			Write-Host "Invalid Windows release provided."
			Write-Host "Use '-Rel List' for a list of available $Selected releases or '-Rel Latest' for latest."
		}
		exit 1
	}

	# Windows Release selection => Populate Product Edition
	$editions = Get-Windows-Editions $winVersionId $winReleaseId
	if ($Ed -eq "List") {
		Write-Host "Please select a Windows Edition (-Ed) for ${Selected}:"
	}
	foreach($edition in $editions) {
		if ($Ed -eq "List") {
			Write-Host " -" $edition.Edition
		} elseif (!$Ed -or $edition.Edition -match $Ed) {
			if (!$Ed -and $Verbosity -ge 1) {
				Write-Host "No edition specified (-Ed). Defaulting to '$($edition.Edition)'."
			}
			$Selected += "," + $edition.Edition -replace "Windows [0-9\.]*"
			$winEditionId = $edition.Id
			break;
		}
	}
	if ($winEditionId -eq $null) {
		if ($Ed -ne "List") {
			Write-Host "Invalid Windows edition provided."
			Write-Host "Use '-Ed List' for a list of available editions or remove the -Ed parameter to use default."
		}
		exit 1
	}

	# Product Edition selection => Request and populate Languages
	$languages = Get-Windows-Languages $winVersionId $winEditionId
	if (!$languages) {
		exit 3
	}
	if ($Lang -eq "List") {
		Write-Host "Please select a Language (-Lang) for ${Selected}:"
	} elseif ($Lang) {
		# Escape parentheses so that they aren't interpreted as regex
		$Lang = $Lang.replace('(', '\(')
		$Lang = $Lang.replace(')', '\)')
	}
	$i = 0
	foreach ($language in $languages) {
		if ($Lang -eq "List") {
			Write-Host " -" $language.Language
		} elseif ((!$Lang -and $script:SelectedIndex -eq $i) -or ($Lang -and $language.Language -match $Lang)) {
			if (!$Lang -and $Verbosity -ge 1) {
				Write-Host "No language specified (-Lang). Defaulting to '$($language.Language)'."
			}
			$Selected += ", " + $language.Language
			$winLanguageId = $language.Id
			$winLanguageName = $language.Language
			break;
		}
		$i++
	}
	if (!$winLanguageId -or !$winLanguageName) {
		if ($Lang -ne "List") {
			Write-Host "Invalid Windows language provided."
			Write-Host "Use '-Lang List' for a list of available languages or remove the option to use system default."
		}
		exit 1
	}

	# Language selection => Request and populate Arch download links
	$links = Get-Windows-Download-Links $winVersionId $winReleaseId $winEditionId $winLanguageId $winLanguageName
	if (!$links) {
		exit 3
	}
	if ($Arch -eq "List") {
		Write-Host "Please select an Architecture (-Arch) for ${Selected}:"
	}
	$i = 0
	foreach ($link in $links) {
		if ($Arch -eq "List") {
			Write-Host " -" $link.Type
		} elseif ((!$Arch -and $script:SelectedIndex -eq $i) -or ($Arch -and $link.Type -match $Arch)) {
			if (!$Arch -and $Verbosity -ge 1) {
				Write-Host "No architecture specified (-Arch). Defaulting to '$($link.Type)'."
			}
			$Selected += ", [" + $link.Type + "]"
			$winLink = $link
			break;
		}
		$i++
	}
	if ($winLink -eq $null) {
		if ($Arch -ne "List") {
			Write-Host "Invalid Windows architecture provided."
			Write-Host "Use '-Arch List' for a list of available architectures or remove the option to use system default."
		}
		exit 1
	}

	# Arch selection => Return selected download link
	if ($GetUrl) {
		Return $winLink.Link
		$ExitCode = 0
	} else {
		Write-Host "Selected: $Selected"
		$ExitCode = Process-Download-Link $winLink.Link
	}

	# Clean up & exit
	exit $ExitCode
}

# Form creation
$XMLForm = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XAML))
$XAML.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $XMLForm.FindName($_.Name) -Scope Script }
$XMLForm.Title = $AppTitle
if ($Icon) {
	$XMLForm.Icon = $Icon
} else {
	$XMLForm.Icon = [WinAPI.Utils]::ExtractIcon("imageres.dll", -5205, $true) | ConvertTo-ImageSource
}
if ($Locale.StartsWith("ar") -or $Locale.StartsWith("fa") -or $Locale.StartsWith("he")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$WindowsVersionTitle.Text = Get-Translation("Version")
$Continue.Content = Get-Translation("Continue")
$Back.Content = Get-Translation("Close")

# Windows 7 and non Windows platforms are too much of a liability
if ($winver -le 6.1) {
	Error(Get-Translation("This feature is not available on this platform."))
	exit 403
}

# Populate the Windows versions
$i = 0
$versions = @()
foreach($version in $WindowsVersions) {
	$versions += @(New-Object PsObject -Property @{ Version = $version[0][0]; PageType = $version[0][1]; Index = $i })
	$i++
}
$WindowsVersion.ItemsSource = $versions
$WindowsVersion.DisplayMemberPath = "Version"

# Button Action
$Continue.add_click({
	$script:Stage++
	$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $false
	$Continue.IsEnabled = $false
	$Back.IsEnabled = $false
	Refresh-Control($Continue)
	Refresh-Control($Back)

	switch ($Stage) {

		1 { # Windows Version selection
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			if ($WindowsVersion.SelectedValue.Version.StartsWith("Windows")) {
				Check-Locale
			}
			$releases = Get-Windows-Releases $WindowsVersion.SelectedValue.Index
			$script:WindowsRelease = Add-Entry $Stage "Release" $releases
			$Back.Content = Get-Translation($English[8])
			$XMLForm.Title = $AppTitle
		}

		2 { # Windows Release selection => Populate Product Edition
			$editions = Get-Windows-Editions $WindowsVersion.SelectedValue.Index $WindowsRelease.SelectedValue.Index
			$script:ProductEdition = Add-Entry $Stage "Edition" $editions
		}

		3 { # Product Edition selection => Request and populate languages
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$languages = Get-Windows-Languages $WindowsVersion.SelectedValue.Index $ProductEdition.SelectedValue.Id
			if ($languages.Length -eq 0) {
				break
			}
			$script:Language = Add-Entry $Stage "Language" $languages "DisplayLanguage"
			$Language.SelectedIndex = $script:SelectedIndex
			$XMLForm.Title = $AppTitle
		}

		4 { # Language selection => Request and populate Arch download links
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$links = Get-Windows-Download-Links $WindowsVersion.SelectedValue.Index $WindowsRelease.SelectedValue.Index $ProductEdition.SelectedValue.Id $Language.SelectedValue.Id $Language.SelectedValue.Language
			if ($links.Length -eq 0) {
				break
			}
			$script:Architecture = Add-Entry $Stage "Architecture" $links "Type"
			if ($PipeName) {
				$XMLForm.Height += $dh / 2;
				$Margin = $Continue.Margin
				$top = $Margin.Top
				$Margin.Top += $dh /2
				$Continue.Margin = $Margin
				$Margin = $Back.Margin
				$Margin.Top += $dh / 2
				$Back.Margin = $Margin
				$Margin = $Check.Margin
				$Margin.Top = $top - 2
				$Check.Margin = $Margin
				$Check.Content = Get-Translation($English[13])
				$Check.Visibility = "Visible"
			}
			$Architecture.SelectedIndex = $script:SelectedIndex
			$Continue.Content = Get-Translation("Download")
			$XMLForm.Title = $AppTitle
		}

		5 { # Arch selection => Return selected download link
			$script:ExitCode = Process-Download-Link $Architecture.SelectedValue.Link
			$XMLForm.Close()
		}
	}
	$Continue.IsEnabled = $true
	if ($Stage -ge 0) {
		$Back.IsEnabled = $true
	}
})

$Back.add_click({
	if ($Stage -eq 0) {
		$XMLForm.Close()
	} else {
		$XMLGrid.Children.RemoveAt(2 * $Stage + 3)
		$XMLGrid.Children.RemoveAt(2 * $Stage + 2)
		$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $true
		$dh2 = $dh
		if ($Stage -eq 4 -and $PipeName) {
			$Check.Visibility = "Collapsed"
			$dh2 += $dh / 2
		}
		$XMLForm.Height -= $dh2;
		$Margin = $Continue.Margin
		$Margin.Top -= $dh2
		$Continue.Margin = $Margin
		$Margin = $Back.Margin
		$Margin.Top -= $dh2
		$Back.Margin = $Margin
		$script:Stage = $Stage - 1
		$XMLForm.Title = $AppTitle
		if ($Stage -eq 0) {
			$Back.Content = Get-Translation("Close")
		} else {
			$Continue.Content = Get-Translation("Continue")
			Refresh-Control($Continue)
		}
	}
})

# Display the dialog
$XMLForm.Add_Loaded({$XMLForm.Activate()})
$XMLForm.ShowDialog() | Out-Null

# Clean up & exit
exit $ExitCode

# SIG # Begin signature block
# MIIkWQYJKoZIhvcNAQcCoIIkSjCCJEYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAjh2Jm/Ps1bMJ+
# sT/W5vOz5r/TXIsYeeHLcOUOP97+C6CCElkwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYcMIIEBKADAgECAhAz1wio
# kUBTGeKlu9M5ua1uMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAs
# BgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBFViBSMzYwggGi
# MA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQC70f4et0JbePWQp64sg/GNIdMw
# hoV739PN2RZLrIXFuwHP4owoEXIEdiyBxasSekBKxRDogRQ5G19PB/YwMDB/NSXl
# wHM9QAmU6Kj46zkLVdW2DIseJ/jePiLBv+9l7nPuZd0o3bsffZsyf7eZVReqskmo
# PBBqOsMhspmoQ9c7gqgZYbU+alpduLyeE9AKnvVbj2k4aOqlH1vKI+4L7bzQHkND
# brBTjMJzKkQxbr6PuMYC9ruCBBV5DFIg6JgncWHvL+T4AvszWbX0w1Xn3/YIIq62
# 0QlZ7AGfc4m3Q0/V8tm9VlkJ3bcX9sR0gLqHRqwG29sEDdVOuu6MCTQZlRvmcBME
# Jd+PuNeEM4xspgzraLqVT3xE6NRpjSV5wyHxNXf4T7YSVZXQVugYAtXueciGoWnx
# G06UE2oHYvDQa5mll1CeHDOhHu5hiwVoHI717iaQg9b+cYWnmvINFD42tRKtd3V6
# zOdGNmqQU8vGlHHeBzoh+dYyZ+CcblSGoGSgg8sCAwEAAaOCAWMwggFfMB8GA1Ud
# IwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBSBMpJBKyjNRsjE
# osYqORLsSKk/FDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAT
# BgNVHSUEDDAKBggrBgEFBQcDAzAaBgNVHSAEEzARMAYGBFUdIAAwBwYFZ4EMAQMw
# SwYDVR0fBEQwQjBAoD6gPIY6aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdSb290UjQ2LmNybDB7BggrBgEFBQcBAQRvMG0wRgYI
# KwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0Nv
# ZGVTaWduaW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQBfNqz7+fZyWhS38Asd3tj9lwHS
# /QHumS2G6Pa38Dn/1oFKWqdCSgotFZ3mlP3FaUqy10vxFhJM9r6QZmWLLXTUqwj3
# ahEDCHd8vmnhsNufJIkD1t5cpOCy1rTP4zjVuW3MJ9bOZBHoEHJ20/ng6SyJ6UnT
# s5eWBgrh9grIQZqRXYHYNneYyoBBl6j4kT9jn6rNVFRLgOr1F2bTlHH9nv1HMePp
# GoYd074g0j+xUl+yk72MlQmYco+VAfSYQ6VK+xQmqp02v3Kw/Ny9hA3s7TSoXpUr
# OBZjBXXZ9jEuFWvilLIq0nQ1tZiao/74Ky+2F0snbFrmuXZe2obdq2TWauqDGIgb
# MYL1iLOUJcAhLwhpAuNMu0wqETDrgXkG4UGVKtQg9guT5Hx2DJ0dJmtfhAH2KpnN
# r97H8OQYok6bLyoMZqaSdSa+2UA1E2+upjcaeuitHFFjBypWBmztfhj24+xkc6Zt
# CDaLrw+ZrnVrFyvCTWrDUUZBVumPwo3/E3Gb2u2e05+r5UWmEsUUWlJBl6MGAAjF
# 5hzqJ4I8O9vmRsTvLQA1E802fZ3lqicIBczOwDYOSxlP0GOabb/FKVMxItt1UHeG
# 0PL4au5rBhs+hSMrl8h+eplBDN1Yfw6owxI9OjWb4J0sjBeBVESoeh2YnZZ/WVim
# VGX/UUIL+Efrz/jlvzCCBsIwggUqoAMCAQICEQC/sVABu/WS1JYqd5fqc2+jMA0G
# CSqGSIb3DQEBCwUAMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExp
# bWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBF
# ViBSMzYwHhcNMjEwOTI5MDAwMDAwWhcNMjQwOTI4MjM1OTU5WjCBmDEPMA0GA1UE
# BRMGNDA3OTUwMRMwEQYLKwYBBAGCNzwCAQMTAklFMR0wGwYDVQQPExRQcml2YXRl
# IE9yZ2FuaXphdGlvbjELMAkGA1UEBhMCSUUxEDAOBgNVBAgMB0RvbmVnYWwxGDAW
# BgNVBAoMD0FrZW8gQ29uc3VsdGluZzEYMBYGA1UEAwwPQWtlbyBDb25zdWx0aW5n
# MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsP4naIgrdLeFHiNbZfuF
# tjkWIo0jOTo0xpiy0eBzx8YYSRMJGAxXlaKIN+Sq15Te16nW7jWmdh1WGUwC3/9a
# HhPc9pJk5qGBZ2O3mOdLpoe03aKEPqlHlcgic0bXxZ3CVc/gkDb71q4jAZYMU3Ii
# uD1887ib9Zpis3MnC04zK+ZugpBFjsWajnxY6bR19F+P34I6lS9G7lAKZogbux3g
# w2OOo2NHUmOFrsCeLXFRSmFHcjFwk2Mv9B2o34UsQpcfVCuAwnCfPMlbHiIom+BV
# cKJlmbgTkTvmN6eWMSdgG0whMUDjwEcfoBpd5VZq2275kgxgJI+NebT/4RGVx0U/
# grKF4X2WWyBA/jikAOMWp7BsTbIsQdpsCVxwR+b3Y04LNk0SOaCzFVSug3G7EvWM
# ylpkH+bfc2SYC0H76iEZo3pA7NifEtjY0xyTAAijolG/fldjsypxDYobZm3hIpgo
# 8oHP/spHKy1cWUJig/XZ3kI5KTTC/o3Wz1zPg7nUQ4WAG9VdgNTtAeWJUY/yE0gh
# eXmZ+Dm0bkHD4dTTC6QLehBj6//97tmbYEYq6WCRxGtxqJVCr+KbkxTh4DCNjTE3
# Xxlkldxd8Oe+Gbqi5MgVHWlHOO4iwpygRsWK1rHjQCktxUZoomeDiqIG0N0f6RXh
# 3khwwxinvStxYwFNz6o5V/UCAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFIEykkEr
# KM1GyMSixio5EuxIqT8UMB0GA1UdDgQWBBQMqWgdye+tyAoAMRo20NXirVSc/zAO
# BgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcD
# AzARBglghkgBhvhCAQEEBAMCBBAwSQYDVR0gBEIwQDA1BgwrBgEEAbIxAQIBBgEw
# JTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwBwYFZ4EMAQMw
# SwYDVR0fBEQwQjBAoD6gPIY6aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljQ29kZVNpZ25pbmdDQUVWUjM2LmNybDB7BggrBgEFBQcBAQRvMG0wRgYI
# KwYBBQUHMAKGOmh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0Nv
# ZGVTaWduaW5nQ0FFVlIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNl
# Y3RpZ28uY29tMCQGA1UdEQQdMBugGQYIKwYBBQUHCAOgDTALDAlJRS00MDc5NTAw
# DQYJKoZIhvcNAQELBQADggGBADVgKUXFLzqffLRAF5qyixRuIeEqQ7Al8ku2DlbJ
# WvWHhZoaKaS2ZmjZ/XNMlg1re4FatvwSbNCb0CL7pC81TrCk4qVEXnuY8xdDfQPe
# 3Do922CFG6GrQWQ4C/ShFWqGMlZq2+Oxwj+iGSKS5VDDVQOya7G5StVvvIc4uSxX
# S6rsNC65oFbTQqkGe9EzIakNkY0Hzh6s6O12+1HXgkZsKlPbpeoPIHV+t9Tny65e
# sqn/MUVE1qecEEv72UveyVsyi96OgEPXe/yaiiIO6aSVsQGey98i9HfAayyH7KKZ
# QTYOb9goARWPNlkKbyF9bndu5kLWIlZcOS7IIznOcS4y1J5ZJewBRH4kbuNfCbSl
# HMZS/rmpFprXXFdje6TRXwgvBs6UOR1zTe5ycumyo5FYBVEFGR1Ps6ZC3z62yLPk
# pb5YSma1/ut/KplOxOnK74ELd/vTS2i10qmsqP5+m+U2jznmCEwm8g8V1mg94acL
# iyM9uR5+U3y6OrVRkMnG9K9ZuTGCEVYwghFSAgEBMGwwVzELMAkGA1UEBhMCR0Ix
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJs
# aWMgQ29kZSBTaWduaW5nIENBIEVWIFIzNgIRAL+xUAG79ZLUlip3l+pzb6MwDQYJ
# YIZIAWUDBAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG
# 9w0BCQQxIgQgHlmtppW7dRXERIdx6h9gmYaf14g6mpSocdl2esDx9G4wDQYJKoZI
# hvcNAQEBBQAEggIAkSfCAEIF2MELdBv1uNcUNWluCCGyBBYnReoXUsGXnz5HEvX7
# UIW7alPIAYhZtFHkXR6mg6D/B6v+tDa0oJIJjlqqtoI0kEbK0dwxyIs3uTF647o6
# H74NemKvYO8yIFKyXnmtd0UIW06BPLDFQPKOD+W9gT/l54k0vQtZLvpTr6hXEtuv
# fZpff1v7MwS+jAjneBP805QKpUmvoyTHAC4INu9HXLjEPCaFVSv/g29PHLLFtSo8
# wCwdsb5tbZuapiF/djtjwShjIOvK4vkv1iyaoUpBm6SPa0qPKwuiq0fRXQ4mu6B+
# 5XxaLl4aPGUCgSUj1PRfsebJEawbJ6czIjwS7Kw1B+8ZTV/6P85U5+HOFWHfZALx
# SrXjX2n5jriAR0FH7LPtMlBrU3cf9+b4+kwq0Ld0e5erYN3lQNjny3MW23skqvBy
# 3YpyHgZrPXA6pq0cls/dwdsdRhq1uQ80BlS0rWTHoI44Hr5/H3kfMsGlk1ZdR9EJ
# pze9mj2SpB+2y3a6BrGMXjp8XQmx57MJDELOcMWKsezPCN3wWHtd9bQ2nxW0OyGw
# pshm1fPjM4lwWvUrH0/9vy/D6tWLwPZXekVedpPGR/oqlRDii+1x/PAuAcOb9u+X
# h+2uOLaos6jR71g8gsNGMUQMuKN9XNvuxFilcl9fc+0Q91vt6ToRob9WNBmhgg49
# MIIOOQYKKwYBBAGCNwMDATGCDikwgg4lBgkqhkiG9w0BBwKggg4WMIIOEgIBAzEN
# MAsGCWCGSAFlAwQCATCCAQ8GCyqGSIb3DQEJEAEEoIH/BIH8MIH5AgEBBgtghkgB
# hvhFAQcXAzAxMA0GCWCGSAFlAwQCAQUABCCJ1gJ+cKbY+3i0FzAkHm4fzyZ8m0bz
# g0Hf+0cQc0Q13QIVAN9FrYgBhZZ+Y7+t9o6rjDNOP8kPGA8yMDIzMDkwODE3MzA0
# OVowAwIBHqCBhqSBgzCBgDELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVj
# IENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMTEw
# LwYDVQQDEyhTeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIFNpZ25lciAtIEcz
# oIIKizCCBTgwggQgoAMCAQICEHsFsdRJaFFE98mJ0pwZnRIwDQYJKoZIhvcNAQEL
# BQAwgb0xCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5WZXJpU2lnbiwgSW5jLjEfMB0G
# A1UECxMWVmVyaVNpZ24gVHJ1c3QgTmV0d29yazE6MDgGA1UECxMxKGMpIDIwMDgg
# VmVyaVNpZ24sIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTE4MDYGA1UE
# AxMvVmVyaVNpZ24gVW5pdmVyc2FsIFJvb3QgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkwHhcNMTYwMTEyMDAwMDAwWhcNMzEwMTExMjM1OTU5WjB3MQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNVBAsTFlN5bWFu
# dGVjIFRydXN0IE5ldHdvcmsxKDAmBgNVBAMTH1N5bWFudGVjIFNIQTI1NiBUaW1l
# U3RhbXBpbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC7WZ1Z
# VU+djHJdGoGi61XzsAGtPHGsMo8Fa4aaJwAyl2pNyWQUSym7wtkpuS7sY7Phzz8L
# VpD4Yht+66YH4t5/Xm1AONSRBudBfHkcy8utG7/YlZHz8O5s+K2WOS5/wSe4eDnF
# hKXt7a+Hjs6Nx23q0pi1Oh8eOZ3D9Jqo9IThxNF8ccYGKbQ/5IMNJsN7CD5N+Qq3
# M0n/yjvU9bKbS+GImRr1wOkzFNbfx4Dbke7+vJJXcnf0zajM/gn1kze+lYhqxdz0
# sUvUzugJkV+1hHk1inisGTKPI8EyQRtZDqk+scz51ivvt9jk1R1tETqS9pPJnONI
# 7rtTDtQ2l4Z4xaE3AgMBAAGjggF3MIIBczAOBgNVHQ8BAf8EBAMCAQYwEgYDVR0T
# AQH/BAgwBgEB/wIBADBmBgNVHSAEXzBdMFsGC2CGSAGG+EUBBxcDMEwwIwYIKwYB
# BQUHAgEWF2h0dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUFBwICMBkaF2h0
# dHBzOi8vZC5zeW1jYi5jb20vcnBhMC4GCCsGAQUFBwEBBCIwIDAeBggrBgEFBQcw
# AYYSaHR0cDovL3Muc3ltY2QuY29tMDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9z
# LnN5bWNiLmNvbS91bml2ZXJzYWwtcm9vdC5jcmwwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0yMDQ4LTMwHQYD
# VR0OBBYEFK9j1sqjToVy4Ke8QfMpojh/gHViMB8GA1UdIwQYMBaAFLZ3+mlIR59T
# EtXC6gcydgfRlwcZMA0GCSqGSIb3DQEBCwUAA4IBAQB16rAt1TQZXDJF/g7h1E+m
# eMFv1+rd3E/zociBiPenjxXmQCmt5l30otlWZIRxMCrdHmEXZiBWBpgZjV1x8viX
# vAn9HJFHyeLojQP7zJAv1gpsTjPs1rSTyEyQY0g5QCHE3dZuiZg8tZiX6KkGtwnJ
# j1NXQZAv4R5NTtzKEHhsQm7wtsX4YVxS9U72a433Snq+8839A9fZ9gOoD+NT9wp1
# 7MZ1LqpmhQSZt/gGV+HGDvbor9rsmxgfqrnjOgC/zoqUywHbnsc4uw9Sq9HjlANg
# Ck2g/idtFDL8P5dA4b+ZidvkORS92uTTw+orWrOVWFUEfcea7CMDjYUq0v+uqWGB
# MIIFSzCCBDOgAwIBAgIQe9Tlr7rMBz+hASMEIkFNEjANBgkqhkiG9w0BAQsFADB3
# MQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xHzAd
# BgNVBAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxKDAmBgNVBAMTH1N5bWFudGVj
# IFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EwHhcNMTcxMjIzMDAwMDAwWhcNMjkwMzIy
# MjM1OTU5WjCBgDELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBv
# cmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMTEwLwYDVQQD
# EyhTeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIFNpZ25lciAtIEczMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArw6Kqvjcv2l7VBdxRwm9jTyB+HQV
# d2eQnP3eTgKeS3b25TY+ZdUkIG0w+d0dg+k/J0ozTm0WiuSNQI0iqr6nCxvSB7Y8
# tRokKPgbclE9yAmIJgg6+fpDI3VHcAyzX1uPCB1ySFdlTa8CPED39N0yOJM/5Sym
# 81kjy4DeE035EMmqChhsVWFX0fECLMS1q/JsI9KfDQ8ZbK2FYmn9ToXBilIxq1vY
# yXRS41dsIr9Vf2/KBqs/SrcidmXs7DbylpWBJiz9u5iqATjTryVAmwlT8ClXhVhe
# 6oVIQSGH5d600yaye0BTWHmOUjEGTZQDRcTOPAPstwDyOiLFtG/l77CKmwIDAQAB
# o4IBxzCCAcMwDAYDVR0TAQH/BAIwADBmBgNVHSAEXzBdMFsGC2CGSAGG+EUBBxcD
# MEwwIwYIKwYBBQUHAgEWF2h0dHBzOi8vZC5zeW1jYi5jb20vY3BzMCUGCCsGAQUF
# BwICMBkaF2h0dHBzOi8vZC5zeW1jYi5jb20vcnBhMEAGA1UdHwQ5MDcwNaAzoDGG
# L2h0dHA6Ly90cy1jcmwud3Muc3ltYW50ZWMuY29tL3NoYTI1Ni10c3MtY2EuY3Js
# MBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMA4GA1UdDwEB/wQEAwIHgDB3BggrBgEF
# BQcBAQRrMGkwKgYIKwYBBQUHMAGGHmh0dHA6Ly90cy1vY3NwLndzLnN5bWFudGVj
# LmNvbTA7BggrBgEFBQcwAoYvaHR0cDovL3RzLWFpYS53cy5zeW1hbnRlYy5jb20v
# c2hhMjU2LXRzcy1jYS5jZXIwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVT
# dGFtcC0yMDQ4LTYwHQYDVR0OBBYEFKUTAamfhcwbbhYeXzsxqnk2AHsdMB8GA1Ud
# IwQYMBaAFK9j1sqjToVy4Ke8QfMpojh/gHViMA0GCSqGSIb3DQEBCwUAA4IBAQBG
# nq/wuKJfoplIz6gnSyHNsrmmcnBjL+NVKXs5Rk7nfmUGWIu8V4qSDQjYELo2JPoK
# e/s702K/SpQV5oLbilRt/yj+Z89xP+YzCdmiWRD0Hkr+Zcze1GvjUil1AEorpczL
# m+ipTfe0F1mSQcO3P4bm9sB/RDxGXBda46Q71Wkm1SF94YBnfmKst04uFZrlnCOv
# WxHqcalB+Q15OKmhDc+0sdo+mnrHIsV0zd9HCYbE/JElshuW6YUI6N3qdGBuYKVW
# eg3IRFjc5vlIFJ7lv94AvXexmBRyFCTfxxEsHwA/w0sUxmcczB4Go5BfXFSLPuMz
# W4IPxbeGAk5xn+lmRT92MYICWjCCAlYCAQEwgYswdzELMAkGA1UEBhMCVVMxHTAb
# BgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBU
# cnVzdCBOZXR3b3JrMSgwJgYDVQQDEx9TeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1w
# aW5nIENBAhB71OWvuswHP6EBIwQiQU0SMAsGCWCGSAFlAwQCAaCBpDAaBgkqhkiG
# 9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIzMDkwODE3MzA0
# OVowLwYJKoZIhvcNAQkEMSIEIOlPG+ScXcg58Jy8YZVYx+MSPoHLFHnQexxjBwsE
# YjviMDcGCyqGSIb3DQEJEAIvMSgwJjAkMCIEIMR0znYAfQI5Tg2l5N58FMaA+eKC
# ATz+9lPvXbcf32H4MAsGCSqGSIb3DQEBAQSCAQBFLhAwze81QjMjju80z0pzfNZO
# sqoCJCLFSqz02v61h/vQ54WqEZv/6g6sGQ0imYVh8I1t3W85lNVvYu1g8MenD5qd
# 0ffyMbaEZO01C2n3Up5kymTy00ZcgB7RWwkAA/v6cK+p+SJ6cBWikOSZLQrTB2ky
# X5p3fd5ox0i4G1LTFNw98v3ax7ylgO7ub4p72BVMIXqzxyRBsm+KWriQ3vCjRXf6
# YcRoIUrYY5Sack7A/jPjh41HeQJr9vmXss/j6SFvaJZYDszrFQCr1dsDQiE0M8bc
# YG9xE7np/Ft+KIZY3zI5iAta9KZKcq5LbFe0VuwqVxslgEwEW5ekfPmCPtNG
# SIG # End signature block
