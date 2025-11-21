#
# Fido v1.67 - ISO Downloader, for Microsoft Windows and UEFI Shell
# Copyright © 2019-2025 Pete Batard <pete@akeo.ie>
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
	[string]$AppTitle = "Fido - ISO Downloader",
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
	# (Optional) Specify the architecture of the underlying CPU.
	# This avoids a VERY TIME CONSUMING call to WMI to autodetect the arch.
	[string]$PlatformArch,
	# (Optional) Increase verbosity
	[switch]$Verbose = $false,
	# (Optional) Produce debugging information
	[switch]$Debug = $false
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
$WindowsVersions = @(
	@(
		@("Windows 11", "windows11"),
		@(
			"25H2 (Build 26200.6584 - 2025.10)",
			# Thanks to Microsoft's hare-brained decision not to treat ARM64 as a CPU arch,
			# like they did for x86 and x64, we have to handle multiple IDs for each release...
			@("Windows 11 Home/Pro/Edu", @(3262, 3265)),
			@("Windows 11 Home China ", @(3263, 3266)),
			@("Windows 11 Pro China ", @(3264, 3267))
		)
	),
	@(
		@("Windows 10", "Windows10ISO"),
		@(
			"22H2 v1 (Build 19045.2965 - 2023.05)",
			@("Windows 10 Home/Pro/Edu", 2618),
			@("Windows 10 Home China ", 2378)
		)
	)
	@(
		@("UEFI Shell 2.2", "UEFI_SHELL 2.2"),
		@(
			"25H2 (edk2-stable202511)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"25H1 (edk2-stable202505)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"24H2 (edk2-stable202411)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"24H1 (edk2-stable202405)",
			@("Release", 0),
			@("Debug", 1)
		),
		@(
			"23H2 (edk2-stable202311)",
			@("Release", 0),
			@("Debug", 1)
		),
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

# Get the underlying *native* CPU architecture
function Get-Arch
{
	$Arch = Get-CimInstance -ClassName Win32_Processor | Select-Object -ExpandProperty Architecture
	switch($Arch) {
	0  { return "x86" }
	1  { return "MIPS" }
	2  { return "Alpha" }
	3  { return "PowerPC" }
	5  { return "ARM32" }
	6  { return "IA64" }
	9  { return "x64" }
	12 { return "ARM64" }
	default { return "Unknown"}
	}
}

# Convert a Microsoft arch type code to a formal architecture name
function Get-Arch-From-Type([int]$Type)
{
	switch($Type) {
	0 { return "x86" }
	1 { return "x64" }
	2 { return "ARM64" }
	default { return "Unknown"}
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
$DefaultTimeout = 30
$dh = 58
$Stage = 0
$SelectedIndex = 0
$ltrm = "‎"
if ($Cmd) {
	$ltrm = ""
}
$MaxStage = 4
# Can't reuse the same sessionId for x64 and ARM64. The Microsoft servers
# are purposefully designed to ever process one specific download request
# that matches the last SKUs retrieved.
$SessionId = @($null) * 2
$ExitCode = 100
$Locale = $Locale
$OrgId = "y6jn8c31"
$ProfileId = "606624d44113"
$Verbosity = 1
if ($Debug) {
	$Verbosity = 5
} elseif ($Verbose) {
	$Verbosity = 2
} elseif ($Cmd -and $GetUrl) {
	$Verbosity = 0
}
if (!$PlatformArch) {
	$PlatformArch = Get-Arch
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
		Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url | Out-Null
	} catch {
		# Of course PowerShell 7 had to BREAK $_.Exception.Status on timeouts...
		if ($_.Exception.Status -eq "Timeout" -or $_.Exception.GetType().Name -eq "TaskCanceledException") {
			Write-Host Operation Timed out
		}
		$script:QueryLocale = "en-US"
	}
}

function Get-Code-715-123130-Message
{
	try {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/windows11"
		if ($Verbosity -ge 2) {
			Write-Host Querying $url
		}
		$r = Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url
		# Microsoft's handling of UTF-8 content is soooooooo *UTTERLY BROKEN*!!!
		$r = [System.Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray())
		# PowerShell 7 forces us to parse the HTML ourselves
		$r = $r -replace "`n" -replace "`r"
		$pattern = '.*<input id="msg-01" type="hidden" value="(.*?)"/>.*'
		$msg = [regex]::Match($r, $pattern).Groups[1].Value
		$msg = $msg -replace "&lt;", "<" -replace "<[^>]+>" -replace "\s+", " "
		if (($msg -eq $null) -or !($msg -match "715-123130")) {
			throw
		}
	} catch {
		$msg  = "Your IP address has been banned by Microsoft for issuing too many ISO download requests or for "
		$msg += "belonging to a region of the world where sanctions currently apply. Please try again later.`r`n"
		$msg += "If you believe this ban to be in error, you can try contacting Microsoft by referring to "
		$msg += "message code 715-123130 and session ID "
	}
	return $msg
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
			if (!($release[0].Contains("China")) -or ($Locale.StartsWith("zh"))) {
				$editions += @(New-Object PsObject -Property @{ Edition = $release[0]; Id = $release[1] })
			}
		}
	}
	return $editions
}

# Return an array of languages for the selected edition
function Get-Windows-Languages([int]$SelectedVersion, [object]$SelectedEdition)
{
	$langs = @()
	if ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
		$langs += @(New-Object PsObject -Property @{ DisplayName = "English (US)"; Name = "en-us"; Data = @($null) })
	} else {
		$languages = [ordered]@{}
		$SessionIndex = 0
		foreach ($EditionId in $SelectedEdition) {
			$SessionId[$SessionIndex] = [guid]::NewGuid()
			# Microsoft download protection now requires the sessionId to be whitelisted through vlscppe.microsoft.com/tags
			$url = "https://vlscppe.microsoft.com/tags"
			$url += "?org_id=" + $OrgId
			$url += "&session_id=" + $SessionId[$SessionIndex]
			if ($Verbosity -ge 2) {
				Write-Host Querying $url
			}
			try {
				Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -MaximumRedirection 0 $url | Out-Null
			} catch {
				Error($_.Exception.Message)
				return @()
			}
			$url = "https://www.microsoft.com/software-download-connector/api/getskuinformationbyproductedition"
			$url += "?profile=" + $ProfileId
			$url += "&productEditionId=" + $EditionId
			$url += "&SKU=undefined"
			$url += "&friendlyFileName=undefined"
			$url += "&Locale=" + $QueryLocale
			$url += "&sessionID=" + $SessionId[$SessionIndex]
			if ($Verbosity -ge 2) {
				Write-Host Querying $url
			}
			try {
				$r = Invoke-RestMethod -UseBasicParsing -TimeoutSec $DefaultTimeout -SessionVariable "Session" $url
				if ($r -eq $null) {
					throw "Could not retrieve languages from server"
				}
				if ($Verbosity -ge 5) {
					Write-Host "=============================================================================="
					Write-Host ($r | ConvertTo-Json)
					Write-Host "=============================================================================="
				}
				if ($r.Errors) {
					throw $r.Errors[0].Value
				}
				foreach ($Sku in $r.Skus) {
					if (!$languages.Contains($Sku.Language)) {
						$languages[$Sku.Language] = @{ DisplayName = $Sku.LocalizedLanguage; Data = @() }
					}
					$languages[$Sku.Language].Data += @{ SessionIndex = $SessionIndex; SkuId = $Sku.Id }
				}
				if ($languages.Length -eq 0) {
					throw "Could not parse languages"
				}
			} catch {
				Error($_.Exception.Message)
				return @()
			}
			$SessionIndex++
		}
		# Need to convert to an array since PowerShell treats them differently from hashtable
		$i = 0
		$script:SelectedIndex = 0
		foreach($language in $languages.Keys) {
			$langs += @(New-Object PsObject -Property @{ DisplayName = $languages[$language].DisplayName; Name = $language; Data = $languages[$language].Data })
			if (Select-Language($language)) {
				$script:SelectedIndex = $i
			}
			$i++
		}
	}
	return $langs
}

# Return an array of download links for each supported arch
function Get-Windows-Download-Links([int]$SelectedVersion, [int]$SelectedRelease, [object]$SelectedEdition, [PSCustomObject]$SelectedLanguage)
{
	$links = @()
	if ($WindowsVersions[$SelectedVersion][0][1].StartsWith("UEFI_SHELL")) {
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
			$links += @(New-Object PsObject -Property @{ Arch = $archs; Url = $link })
		} catch {
			Error($_.Exception.Message)
			return @()
		}
	} else {
		foreach ($Entry in $SelectedLanguage.Data) {
			$url = "https://www.microsoft.com/software-download-connector/api/GetProductDownloadLinksBySku"
			$url += "?profile=" + $ProfileId
			$url += "&productEditionId=undefined"
			$url += "&SKU=" + $Entry.SkuId
			$url += "&friendlyFileName=undefined"
			$url += "&Locale=" + $QueryLocale
			$url += "&sessionID=" + $SessionId[$Entry.SessionIndex]
			if ($Verbosity -ge 2) {
				Write-Host Querying $url
			}
			try {
				# Must add a referer for this request, else Microsoft's servers may deny it
				$ref = "https://www.microsoft.com/software-download/windows11"
				$r = Invoke-RestMethod -Headers @{ "Referer" = $ref } -UseBasicParsing -TimeoutSec $DefaultTimeout -SessionVariable "Session" $url
				if ($r -eq $null) {
					throw "Could not retrieve architectures from server"
				}
				if ($Verbosity -ge 5) {
					Write-Host "=============================================================================="
					Write-Host ($r | ConvertTo-Json)
					Write-Host "=============================================================================="
				}
				if ($r.Errors) {
					if ( $r.Errors[0].Type -eq 9) {
						$msg = Get-Code-715-123130-Message
						throw $msg + $SessionId[$Entry.SessionIndex] + "."
					} else {
						throw $r.Errors[0].Value
					}
				}
				foreach ($ProductDownloadOption in $r.ProductDownloadOptions) {
					$links += @(New-Object PsObject -Property @{ Arch = (Get-Arch-From-Type $ProductDownloadOption.DownloadType); Url = $ProductDownloadOption.Uri })
				}
				if ($links.Length -eq 0) {
					throw "Could not retrieve ISO download links"
				}
			} catch {
				Error($_.Exception.Message)
				return @()
			}
			$SessionIndex++
		}
		$i = 0
		$script:SelectedIndex = 0
		foreach($link in $links) {
			if ($link.Arch -eq $PlatformArch) {
				$script:SelectedIndex = $i
			}
			$i++
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
				$str_size = (Invoke-WebRequest -UseBasicParsing -TimeoutSec $DefaultTimeout -Uri $Url -Method Head).Headers.'Content-Length'
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
	$winLanguage = $null
	foreach ($language in $languages) {
		if ($Lang -eq "List") {
			Write-Host " -" $language.Name
		} elseif ((!$Lang -and $script:SelectedIndex -eq $i) -or ($Lang -and $language.Name -match $Lang)) {
			if (!$Lang -and $Verbosity -ge 1) {
				Write-Host "No language specified (-Lang). Defaulting to '$($language.Name)'."
			}
			$Selected += ", " + $language.Name
			$winLanguage = $language
			break;
		}
		$i++
	}
	if ($winLanguage -eq $null) {
		if ($Lang -ne "List") {
			Write-Host "Invalid Windows language provided."
			Write-Host "Use '-Lang List' for a list of available languages or remove the option to use system default."
		}
		exit 1
	}

	# Language selection => Request and populate Arch download links
	$links = Get-Windows-Download-Links $winVersionId $winReleaseId $winEditionId $winLanguage
	if (!$links) {
		exit 3
	}
	if ($Arch -eq "List") {
		Write-Host "Please select an Architecture (-Arch) for ${Selected}:"
	}
	$i = 0
	foreach ($link in $links) {
		if ($Arch -eq "List") {
			Write-Host " -" $link.Arch
		} elseif ((!$Arch -and $script:SelectedIndex -eq $i) -or ($Arch -and $link.Arch -match $Arch)) {
			if (!$Arch -and $Verbosity -ge 1) {
				Write-Host "No architecture specified (-Arch). Defaulting to '$($link.Arch)'."
			}
			$Selected += ", [" + $link.Arch + "]"
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
		return $winLink.Url
		$ExitCode = 0
	} else {
		Write-Host "Selected: $Selected"
		$ExitCode = Process-Download-Link $winLink.Url
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
			$script:Language = Add-Entry $Stage "Language" $languages "DisplayName"
			$Language.SelectedIndex = $script:SelectedIndex
			$XMLForm.Title = $AppTitle
		}

		4 { # Language selection => Request and populate Arch download links
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$links = Get-Windows-Download-Links $WindowsVersion.SelectedValue.Index $WindowsRelease.SelectedValue.Index $ProductEdition.SelectedValue.Id $Language.SelectedValue
			if ($links.Length -eq 0) {
				break
			}
			$script:Architecture = Add-Entry $Stage "Architecture" $links "Arch"
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
			$script:ExitCode = Process-Download-Link $Architecture.SelectedValue.Url
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
# MIIteQYJKoZIhvcNAQcCoIItajCCLWYCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDPOcMiJnD+xuEQ
# J1yFd1tPKQrDNQsWGhA+D91xgJ9imKCCEkAwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# VGX/UUIL+Efrz/jlvzCCBqkwggURoAMCAQICEDfFCjwdoANxxw3HxiaQL+UwDQYJ
# KoZIhvcNAQELBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGlt
# aXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgQ29kZSBTaWduaW5nIENBIEVW
# IFIzNjAeFw0yNDA4MjgwMDAwMDBaFw0yNzA4MjgyMzU5NTlaMIGTMQ8wDQYDVQQF
# EwY0MDc5NTAxEzARBgsrBgEEAYI3PAIBAxMCSUUxGDAWBgNVBA8TD0J1c2luZXNz
# IEVudGl0eTELMAkGA1UEBhMCSUUxEDAOBgNVBAgMB0RvbmVnYWwxGDAWBgNVBAoM
# D0FrZW8gQ29uc3VsdGluZzEYMBYGA1UEAwwPQWtlbyBDb25zdWx0aW5nMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAqpN7vevPy6Ir46imPS9uMM86vroQ
# e9gcAMNYKW+RXzSJfi79vZOzABoVPZ72rSwODApd89w95Z5FqGjwhaIu04lCHt6H
# mOL+TR9xdo2WWFWXGh7yC5jmvMofk54A6h7klEd2u3f4aTjy9sVr1uUmjA9KA1o8
# HBgid5+HL57I9XprTRXGtTHAzHJyX1FEEGGKv9CtxEUaIr1/mIFpsNLZN2NfOoIu
# PPpxMypcXISDecJApvKxhqBte5SMhKa5zlI5omyizesQJZoRGjVfe83Ntb7kykFS
# Du1hmJMbtV0mM8yrhoUy+QAKp2ZhctkbPmWDNVLDK51GnfOgfmgaMQvm9RZQeh1N
# OT+fbUxHakG14kdARprNWJbBsJX5kLvzzTL4xbz+hPRT4jUkRZgQ9eDz1+a5Qa4Q
# FJtosRbwaJNuX9YQyrda1Jy2yJEVXanaRS8R0WM6wcYL47KMmxhz37HGr5zek9I+
# rfQ+/Qt+imZ/q1cYEuvx9owSVbpZAV1/g5z3AwH4ue+msMlY3bxwBfeEPHFnNdxh
# Dg7jlggohX79KL5e85FQs3iQpwXvGDlUjvS6KG+Rv3DokvZS9WSWB4REHmC/Cywu
# LQh3VF1Ezko3HMOG+nQptBNJ2Vk9JRq8mh317Tzv9dsoVWS6Vv1O2nyGbWZfjkn3
# ayT+S5SopUo/PcECAwEAAaOCAbIwggGuMB8GA1UdIwQYMBaAFIEykkErKM1GyMSi
# xio5EuxIqT8UMB0GA1UdDgQWBBRU0FFbeE+nxVuayZAwm7BZrYKDHzAOBgNVHQ8B
# Af8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzBJBgNV
# HSAEQjBAMDUGDCsGAQQBsjEBAgEGATAlMCMGCCsGAQUFBwIBFhdodHRwczovL3Nl
# Y3RpZ28uY29tL0NQUzAHBgVngQwBAzBLBgNVHR8ERDBCMECgPqA8hjpodHRwOi8v
# Y3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBRVZSMzYu
# Y3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6aHR0cDovL2NydC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQUVWUjM2LmNydDAjBggr
# BgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wJAYDVR0RBB0wG6AZBggr
# BgEFBQcIA6ANMAsMCUlFLTQwNzk1MDANBgkqhkiG9w0BAQsFAAOCAYEAs2WyIJRC
# l+lgha7wuLYXCdbZbx4K02SyteLCXXRYuQ/+o7kX2P3BQuqNZXBQ4y+xbuOTqNOY
# R6VK7QrLvYaiMJky5qZY3lQfdsvuGkZmg1XvY1BPXre6B1/HkatGmnqtFUcBBeW4
# wtHOglq96eLHXzXCvS+1xO9wvv7GGB53i+7ePq7ROr717p/V1OUntl5y8nzxyhRI
# ucs6gBX0gbBQljLC16DwZ20NlNhYfi1SF7pSfnWZH/bojOPta3fCmIx7r8tjDu5m
# 4a6KRpYwLMYE9/ZBEBP7JpfiMt42q+QF6fyS8xauGiOGBOZW4ch7Wh+GBoe3JZUu
# UPC4wZDC9LeRKz/otodtloaTEnW9YE9gPmfRttMWaNsQTg6y5sc74qLoVY0RSqcW
# B2KScXAjuVHVkJJcOoPSuLoTjOhK3Ug4XbQmRypdteoizdTSnONGmW84RJyXquzi
# rIjw9CnLTggrZiYi9EZTo7URWNaARqLbSFpu0VMkdOBpWdXq5F6x6jslMYIajzCC
# GosCAQEwazBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgRVYgUjM2
# AhA3xQo8HaADcccNx8YmkC/lMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIB
# DDECMAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEO
# MAwGCisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEIHj+sJZtpA/cwe/Q1zzW8DzN
# 9l8bNLAuuNUfcX9V3Of0MA0GCSqGSIb3DQEBAQUABIICAAxkjERS7j27YsErr4jI
# MEE1dakWq85+vWxuCFsDjdbjtG2jNAJEn/1AoY4xeGEQSW9CCarDZ2Lxe5I2PNqc
# iw8fsIP0+yrGPJytJs3RCU9tfV8GNfqsSiE5C8SJr3KYwvTkjLtjcXTXFpc2qcQH
# l2ehe/p14zrf9+ED8+fG45qDciPZsF2mpej/RTcO3O2wVq7mD2KKpVNjRg6GDcQw
# hc6aWRW7dDaYC71LIVXwcy4mj69+8PecQjR3ojCgCZ23BZPSp5qloORic47C1yEl
# qtkn0TGuf8hRswRWJcTG6zU/L7QMVGbcWAW6rhPMPbuLao/7AmsJMigHmtBMEpR8
# YRU56PluJTmJftQHtM7adiZjarjnQY5n/FJOaYsiU90BDGLsBEo+WyRapjlCh28B
# 71RXCWxsIy2DMY5Xi4IqaZMxs2UgDH4jvyTiQr/5PIG9UIg0xuGJGTvZHwNajdU6
# VWsNHFEOtIvFeYyMXBXD7WpAHJYOnvTzvcGjfE+6u3ZlYGRO3JMKKLTggofv6rzv
# OZtqYFAPCbFyRgrEaNlxcRlrqg9AqDFLhNO5ChmEyrK0PT1U+R59nS6LrdPYOah6
# r0WynpVl3srWfmSW3Y7Oa4yZMCKiDaygsKFxowmdL+PrI9y6PnXVwjD5lr3zLbJp
# E3MScPJj6oOC7sE3M38fvIdroYIXdzCCF3MGCisGAQQBgjcDAwExghdjMIIXXwYJ
# KoZIhvcNAQcCoIIXUDCCF0wCAQMxDzANBglghkgBZQMEAgEFADB4BgsqhkiG9w0B
# CRABBKBpBGcwZQIBAQYJYIZIAYb9bAcBMDEwDQYJYIZIAWUDBAIBBQAEIAYrZ3vU
# tyoFqJmJ1yk2qZhQxUdcBMmg6uO8A2gaoEiZAhEAksRZAueVEMAMOW2Ri+BlhRgP
# MjAyNTExMjEyMTM0MzlaoIITOjCCBu0wggTVoAMCAQICEAqA7xhLjfEFgtHEdqeV
# dGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0z
# NjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1w
# IFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ3xTWcfsLwOvRxUwX
# cGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqVQ+3bzWYesFtkepEr
# vUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjoT1FpS54dNApZfKY6
# 1HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R0V3Zp3DjjANwqAf4
# lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1uSqgr6UnbksIcFJqLbkIXIPb
# cNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3NR39iTTFS+ENTqW8m6TH
# uOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0dVVZw7knh1WZXOLH
# gDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1p6llN3QgshRta6Eq4B40
# h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O65Uck5Wggn8O2klETsJ7u8xE
# ehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPeldYRNMmSF3voIgMFtNGh86w3
# ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwIDAQABo4IBlTCCAZEw
# DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X85FxYxlQQ89hjOgwHwYD
# VR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3Rh
# bXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0
# YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAZSqt8RwnBLmuYEHs
# 0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZhY+hIfP2JkQ38U+w
# tJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/ciZmUnthfAEP1HSh
# TrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk6FxRPyUPxAAYH2Vy
# 1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQUSntbjZ80FU3i54t
# px5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAmaaslNXdCG1+lqvP4FbrQ6IwS
# BXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQFnCEH1Y58678IgmfORBPC1JK
# kYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6JfwyYHXSd+V08X1JUPvB4ILfJdmL
# +66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1qmcwbdUfcSYCn+Own
# cVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlXHAL5SlfYxJ7La54i71McVWRP
# 66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhDBf3Froguzzhk++am
# i+r3Qrx5bIbY3TVzgiFI7Gq3zWcwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIM
# OkmGMA0GCSqGSIb3DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdp
# Q2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERp
# Z2lDZXJ0IFRydXN0ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQy
# MzU5NTlaMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5
# NiBTSEEyNTYgMjAyNSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQC0eDHTCphBcr48RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq
# +RuwOnPhof6pvF4uGjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyF
# Q/4Bt0mAxAHeHYNnQxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOE
# CS1UkxBvMgEdgkFiDNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdg
# lTcaarps0wjUjsZvkgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZ
# a/zbCclF83bRVFLeGkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLr
# fxnGpTXiUOeSLsJygoLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy
# 3tW/AMOMCZIVNSaz7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJW
# nY0v5ydPpOjL6s36czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdg
# JMoiwOrUG2ZdSoQbU2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJ
# SjNm2qA+sdFUeEY0qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkw
# EgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ens
# y04wHwYDVR0jBBgwFoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQD
# AgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNy
# dDBDBgNVHR8EPDA6MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRUcnVzdGVkUm9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglg
# hkgBhv1sBwEwDQYJKoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSm
# f83Qh8WIGjB/T8ObXAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83a
# fsl3YTj+IQhQE7jU/kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5
# nWMQwr8Myb9rEVKChHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ
# 2iA/wdG2th9y1IsA0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu
# 4y81hjajV/gxdEkMx1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgc
# GV00TYr2Lr3ty9qIijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+
# qNNjqFzeGxcytL5TTLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll
# 38F0cuJG7uEBYTptMSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66R
# zIg9sC+NJpud/v4+7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDp
# MPx0LckTetiSuEtQvLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8Wh
# baM2tszWkPZPubdcMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkq
# hkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBB
# c3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5
# WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1K
# PDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2r
# snnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C
# 8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBf
# sXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGY
# QJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8
# rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaY
# dj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+
# wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw
# ++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+N
# P8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7F
# wI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUw
# AwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAU
# Reuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEB
# BG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsG
# AQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAow
# CDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/
# Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLe
# JLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE
# 1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9Hda
# XFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbO
# byMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYID
# fDCCA3gCAQEwfTBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIElu
# Yy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJT
# QTQwOTYgU0hBMjU2IDIwMjUgQ0ExAhAKgO8YS43xBYLRxHanlXRoMA0GCWCGSAFl
# AwQCAQUAoIHRMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0B
# CQUxDxcNMjUxMTIxMjEzNDM5WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTdYjCs
# hgotMGvaOLFoeVIwB/tBfjAvBgkqhkiG9w0BCQQxIgQgnyfi2wN4u2NxScu8KiHZ
# FYMcQlMucBrpz4FXHDzybvQwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgSqA/oizX
# XITFXJOPgo5na5yuyrM/420mmqM08UYRCjMwDQYJKoZIhvcNAQEBBQAEggIAWtxE
# /Go4AtD5ocoX66KSehM3RDkK8cAmUm7KI+qp+n0CCD1fd3i9BW6v0RFtLyHDKJK6
# GDxCkxfUBh2KlT6jwECZHCHhKobPeu+cx2/2nmnUjG6fa51r9Lf9uTF7bEizL4tx
# 0B+rHqIvkcafDuh56NHK9c//01ufvi0LsOL17vqto/5Ayt3b41AvmEVs9BWAitUh
# 0UJiGqsstHPprtsS98nUxdc3BEoMjONR5wEmSyMvQ8Zd6dfEAGhVEA/wUjIpO8eI
# F2kZmqwjBR7/PI930WoQa9LkI6RWT/60ubvIsIMhKQf/tkzA0oNjr84jFbcZiost
# nHemojANe1HBHR4fM/+P8h8R7JKO6VndEafdzDbFA8xt4KRyUaMzQjeSICqJ4uPl
# 6QRT4+ZuWlnFpyFTdrnp0tVfF+lOfH6yIf1OO2PgB/FGTDSjU8MweXksurrqfpb3
# ddNUlRRsh+TfJ1VAiXykpouM7yWedmssz1NMm1k1MfrGPorRAfoKQ/WTtwBK+hM3
# 0beJjlsFbamx3hIEPeJ6odoDu9ItKfLDnkKm2WfZL+Gf8HjYYoJ5g2cS6k91paJP
# JX8HZu0QRpsicvpB27gGLsmjzKYclD0XdifaFeuHb30poxGqmH9kyfXlClPfYJkT
# 3f6tTBMpxo0VxehnVm3WtAZEZwsn/k/VK8DY4Bw=
# SIG # End signature block
