#
# Fido v1.20 - Retail Windows ISO Downloader
# Copyright © 2019-2021 Pete Batard <pete@akeo.ie>
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
	[string]$AppTitle = "Fido - Retail Windows ISO Downloader",
	# (Optional) '|' separated UI localization strings.
	[string]$LocData,
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
	[switch]$GetUrl = $False,
	# (Optional) Increase verbosity
	[switch]$Verbose = $False
)
#endregion

try {
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$Cmd = $False
if ($Win -or $Rel -or $Ed -or $Lang -or $Arch -or $GetUrl) {
	$Cmd = $True
}

#region Assembly Types
$code = @"
[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
[DllImport("user32.dll")]
	public static extern bool ShowWindow(IntPtr handle, int state);

	// Extract an icon from a DLL
	public static Icon ExtractIcon(string file, int number, bool largeIcon)
	{
		IntPtr large, small;
		ExtractIconEx(file, number, out large, out small, 1);
		try {
			return Icon.FromHandle(largeIcon ? large : small);
		} catch {
			return null;
		}
	}
"@

if (!$Cmd) {
	Write-Host Please Wait...
	if ($host.version -ge "7.0") {
		Add-Type -WarningAction Ignore -IgnoreWarnings -MemberDefinition $code -Namespace Gui -UsingNamespace System.Runtime, System.IO, System.Text, System.Drawing, System.Globalization -ReferencedAssemblies System.Drawing.Common -Name Utils -ErrorAction Stop
	} else {
		Add-Type -MemberDefinition $code -Namespace Gui -UsingNamespace System.IO, System.Text, System.Drawing, System.Globalization -ReferencedAssemblies System.Drawing -Name Utils -ErrorAction Stop
	}
	Add-Type -AssemblyName PresentationFramework
	# Hide the powershell window: https://stackoverflow.com/a/27992426/1069307
	[Gui.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0) | Out-Null
}
#endregion

#region Data
$zh = 0x10000
$ko = 0x20000
$WindowsVersions = @(
	@(
		@("Windows 10", "Windows10ISO"),
		@(
			"21H1 (Build 19043.985 - 2021.05)",
			@("Windows 10 Home/Pro", 2033),
			@("Windows 10 Education", 2032),
			@("Windows 10 Home China ", ($zh + 2034))
		),
		@(
			"20H2 (Build 19042.631 - 2020.12)",
			@("Windows 10 Home/Pro", 1882),
			@("Windows 10 Education", 1884),
			@("Windows 10 Home China ", ($zh + 1883))
		),
		@(
			"20H2 (Build 19042.508 - 2020.10)",
			@("Windows 10 Home/Pro", 1807),
			@("Windows 10 Education", 1805),
			@("Windows 10 Home China ", ($zh + 1806))
		),
		@(
			"20H1 (Build 19041.264 - 2020.05)",
			@("Windows 10 Home/Pro", 1626),
			@("Windows 10 Education", 1625),
			@("Windows 10 Home China ", ($zh + 1627))
		),
		@(
			"19H2 (Build 18363.418 - 2019.11)",
			@("Windows 10 Home/Pro", 1429),
			@("Windows 10 Education", 1431),
			@("Windows 10 Home China ", ($zh + 1430))
		),
		@(
			"19H1 (Build 18362.356 - 2019.09)",
			@("Windows 10 Home/Pro", 1384),
			@("Windows 10 Education", 1386),
			@("Windows 10 Home China ", ($zh + 1385))
		),
		@(
			"19H1 (Build 18362.30 - 2019.05)",
			@("Windows 10 Home/Pro", 1214),
			@("Windows 10 Education", 1216),
			@("Windows 10 Home China ", ($zh + 1215))
		),
		@(
			"1809 R2 (Build 17763.107 - 2018.10)",
			@("Windows 10 Home/Pro", 1060),
			@("Windows 10 Education", 1056),
			@("Windows 10 Home China ", ($zh + 1061))
		),
		@(
			"1809 R1 (Build 17763.1 - 2018.09)",
			@("Windows 10 Home/Pro", 1019),
			@("Windows 10 Education", 1021),
			@("Windows 10 Home China ", ($zh + 1020))
		),
		@(
			"1803 (Build 17134.1 - 2018.04)",
			@("Windows 10 Home/Pro", 651),
			@("Windows 10 Education", 655),
			@("Windows 10 1803", 637),
			@("Windows 10 Home China", ($zh + 652))
		),
		@(
			"1709 (Build 16299.15 - 2017.09)",
			@("Windows 10 Home/Pro", 484),
			@("Windows 10 Education", 488),
			@("Windows 10 Home China", ($zh + 485))
		),
		@(
			"1703 [Redstone 2] (Build 15063.0 - 2017.03)",
			@("Windows 10 Home/Pro", 361),
			@("Windows 10 Home/Pro N", 362),
			@("Windows 10 Single Language", 363),
			@("Windows 10 Education", 423),
			@("Windows 10 Education N", 424),
			@("Windows 10 Home China", ($zh + 364))
		),
		@(
			"1607 [Redstone 1] (Build 14393.0 - 2016.07)",
			@("Windows 10 Home/Pro", 244),
			@("Windows 10 Home/Pro N", 245),
			@("Windows 10 Single Language", 246),
			@("Windows 10 Education", 242),
			@("Windows 10 Education N", 243),
			@("Windows 10 China Get Genuine", ($zh + 247))
		),
		@(
			"1511 R3 [Threshold 2] (Build 10586.164 - 2016.04)",
			@("Windows 10 Home/Pro", 178),
			@("Windows 10 Home/Pro N", 183),
			@("Windows 10 Single Language", 184),
			@("Windows 10 Education", 179),
			@("Windows 10 Education N", 181),
			@("Windows 10 KN", ($ko + 182)),
			@("Windows 10 Education KN", ($ko + 180)),
			@("Windows 10 China Get Genuine", ($zh + 185))
		),
		@(
			"1511 R2 [Threshold 2] (Build 10586.104 - 2016.02)",
			@("Windows 10 Home/Pro", 109),
			@("Windows 10 Home/Pro N", 115),
			@("Windows 10 Single Language", 116),
			@("Windows 10 Education", 110),
			@("Windows 10 Education N", 112),
			@("Windows 10 KN", ($ko + 114)),
			@("Windows 10 Education KN", ($ko + 111)),
			@("Windows 10 China Get Genuine", ($zh + 113))
		),
		@(
			"1511 R1 [Threshold 2] (Build 10586.0 - 2015.11)",
			@("Windows 10 Home/Pro", 99),
			@("Windows 10 Home/Pro N", 105),
			@("Windows 10 Single Language", 106),
			@("Windows 10 Education", 100),
			@("Windows 10 Education N", 102),
			@("Windows 10 KN", ($ko + 104)),
			@("Windows 10 Education KN", ($ko + 101)),
			@("Windows 10 China Get Genuine", ($zh + 103))
		),
		@(
			"1507 [Threshold 1] (Build 10240.16384 - 2015.07)",
			@("Windows 10 Home/Pro", 79),
			@("Windows 10 Home/Pro N", 81),
			@("Windows 10 Single Language", 82),
			@("Windows 10 Education", 75)
			@("Windows 10 Education N", 77),
			@("Windows 10 KN", ($ko + 80)),
			@("Windows 10 Education KN", ($ko + 76)),
			@("Windows 10 China Get Genuine", ($zh + 78))
		)
	),
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
		@("Windows 7", "WIN7"),
		@(
			"with SP1 (build 7601)",
			@("Windows 7 Ultimate", 0),
			@("Windows 7 Professional", 1),
			@("Windows 7 Home Premium", 2)
		)
	)
)

$Windows7Versions = @(
	# 0: Windows 7 Ultimate
	@(
		# Need a dummy to prevent PS from coalescing single array entries
		@(""),
		@("English (US)", "en-us",
			@(
				@("x64", "https://download.microsoft.com/download/5/1/9/5195A765-3A41-4A72-87D8-200D897CBE21/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_ULTIMATE_x64FRE_en-us.iso"),
				@("x86", "https://download.microsoft.com/download/1/E/6/1E6B4803-DD2A-49DF-8468-69C0E6E36218/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_ULTIMATE_x86FRE_en-us.iso")
			)
		)
	),
	# 1: Windows 7 Profesional
	@(
		@(""),
		@("English (US)", "en-us",
			@(
				@("x64", "https://download.microsoft.com/download/0/6/3/06365375-C346-4D65-87C7-EE41F55F736B/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_PROFESSIONAL_x64FRE_en-us.iso"),
				@("x86", "https://download.microsoft.com/download/C/0/6/C067D0CD-3785-4727-898E-60DC3120BB14/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_PROFESSIONAL_x86FRE_en-us.iso")
			)
		)
	),
	# 2: Windows 7 Home Premium
	@(
		@(""),
		@("English (US)", "en-us",
			@(
				@("x64", "https://download.microsoft.com/download/E/A/8/EA804D86-C3DF-4719-9966-6A66C9306598/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_HOMEPREMIUM_x64FRE_en-us.iso"),
				@("x86", "https://download.microsoft.com/download/E/D/A/EDA6B508-7663-4E30-86F9-949932F443D0/7601.24214.180801-1700.win7sp1_ldr_escrow_CLIENT_HOMEPREMIUM_x86FRE_en-us.iso")
			)
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
		return $True
	}
	return $False
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
	$Err = $(GetElementById -Request $r -Id "errorModalMessage").innerText
	if (-not $Err) {
		$Err = $Alt
	} else {
		$Err = [System.Text.Encoding]::UTF8.GetString([byte[]][char[]]$Err)
	}
	throw $Err
}

# Translate a message string
function Get-Translation([string]$Text)
{
	if (-not $English -contains $Text) {
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
		$XMLGrid.Children[2 * $script:Stage + 1].IsEnabled = $True
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
$Locale = "en-US"
$RequestData = @{}
# This GUID applies to all visitors, regardless of their locale
$RequestData["GetLangs"] = @("a8f8f489-4c7f-463a-9ca6-5cff94d8d041", "getskuinformationbyproductedition" )
# This GUID applies to visitors of the en-US download page. Other locales may get a different GUID.
$RequestData["GetLinks"] = @("a224afab-2097-4dfa-a2ba-463eb191a285", "GetProductDownloadLinksBySku" )
# Create a semi-random Linux User-Agent string
$FirefoxVersion = Get-Random -Minimum 50 -Maximum 90
$FirefoxDate = Get-RandomDate
$UserAgent = "Mozilla/5.0 (X11; Linux i586; rv:$FirefoxVersion.0) Gecko/$FirefoxDate Firefox/$FirefoxVersion.0"
$Verbosity = 0
if ($Verbose) {
	$Verbosity = 1
}
#endregion

# Localization
$EnglishMessages = "en-US|Version|Release|Edition|Language|Architecture|Download|Continue|Back|Close|Cancel|Error|Please wait...|" +
	"Download using a browser|Temporarily banned by Microsoft for requesting too many downloads - Please try again later...|" +
	"PowerShell 3.0 or later is required to run this script.|Do you want to go online and download it?"
[string[]]$English = $EnglishMessages.Split('|')
[string[]]$Localized = $null
if ($LocData -and (-not $LocData.StartsWith("en-US"))) {
	$Localized = $LocData.Split('|')
	if ($Localized.Length -ne $English.Length) {
		Write-Host "Error: Missing or extra translated messages provided ($($Localized.Length)/$($English.Length))"
		exit 101
	}
	$Locale = $Localized[0]
}
$QueryLocale = $Locale

# Make sure PowerShell 3.0 or later is used (for Invoke-WebRequest)
if ($PSVersionTable.PSVersion.Major -lt 3) {
	Write-Host Error: PowerShell 3.0 or later is required to run this script.
	$Msg = "$(Get-Translation($English[15]))`n$(Get-Translation($English[16]))"
	if ([System.Windows.MessageBox]::Show($Msg, $(Get-Translation("Error")), "YesNo", "Error") -eq "Yes") {
		Start-Process -FilePath https://www.microsoft.com/download/details.aspx?id=34595
	}
	exit 102
}

# Check if the locale we want is available - Fall back to en-US otherwise
function Check-Locale {
	try {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/"
		if (!$Cmd -or $Verbose) {
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
	} else {
		$url = "https://www.microsoft.com/" + $QueryLocale + "/api/controls/contentinclude/html"
		$url += "?pageId=" + $RequestData["GetLangs"][0]
		$url += "&host=www.microsoft.com"
		$url += "&segments=software-download," + $WindowsVersions[$SelectedVersion][0][1] 
		$url += "&query=&action=" + $RequestData["GetLangs"][1]
		$url += "&sessionId=" + $SessionId
		$url += "&productEditionId=" + [Math]::Abs($SelectedEdition)
		$url += "&sdVersion=2"
		if (!$Cmd -or $Verbose) {
			Write-Host Querying $url
		}

		$script:SelectedIndex = 0
		try {
			$r = Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -SessionVariable "Session" $url
			if ($r -match "errorModalMessage") {
				Throw-Error -Req $r -Alt "Could not retrieve languages from server"
			}
			$pattern = '(?s)<select id="product-languages">(.*)?</select>'
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
function Get-Windows-Download-Links([int]$SelectedVersion, [int]$SelectedEdition, [int]$SkuId, [string]$LanguageName)
{
	$links = @()
	if ($WindowsVersions[$SelectedVersion][0][1] -eq "WIN7") {
		foreach ($Version in $Windows7Versions[$SelectedEdition][$SkuId][2]) {
			$links += @(New-Object PsObject -Property @{ Type = $Version[0]; Link = $Version[1] })
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
		if (!$Cmd -or $Verbose) {
			Write-Host Querying $url
		}

		$i = 0
		$script:SelectedIndex = 0

		try {
			$Is64 = [Environment]::Is64BitOperatingSystem
			$r = Invoke-WebRequest -Method Post -UseBasicParsing -UserAgent $UserAgent -WebSession $Session $url
			if ($r -match "errorModalMessage") {
				Throw-Error -Req $r -Alt "Could not retrieve architectures from server"
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
					if (($Is64 -and $json.DownloadType -eq "x64") -or (-not $Is64 -and $json.DownloadType -eq "x86")) {
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
	if ($PipeName -and -not $Check.IsChecked) {
		Send-Message -PipeName $PipeName -Message $Url
	} else {
		if ($Cmd) {
			$pattern = '.*\/(.*\.iso).*'
			$File = [regex]::Match($Url, $pattern).Groups[1].Value	
			Write-Host "Downloading '$File'..."
			Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $File
		} else {
			Write-Host Download Link: $Url
			Start-Process -FilePath $Url
		}
	}
}

if ($Cmd) {
	$winVersionId = $null
	$winReleaseId = $null
	$winEditionId = $null
	$winLanguageId = $null
	$winLanguageName = $null
	$winLink = $null

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
			$Selected += "," + $edition.Edition -replace "Windows [0-9\.]*", ""
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
	if ($winLanguageId -eq $null -or $winLanguageName -eq $null) {
		if ($Lang -ne "List") {
			Write-Host "Invalid Windows language provided."
			Write-Host "Use '-Lang List' for a list of available languages or remove the option to use system default."
		}
		exit 1
	}

	# Language selection => Request and populate Arch download links
	$links = Get-Windows-Download-Links $winVersionId $winEditionId $winLanguageId $winLanguageName
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
			$Selected += ", " + $link.Type
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
		Write-Host $winLink.Link
	} else {
		Write-Host "Selected: $Selected"
		Process-Download-Link $winLink.Link
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
	$XMLForm.Icon = [Gui.Utils]::ExtractIcon("shell32.dll", -41, $true) | ConvertTo-ImageSource
}
if ($Locale.StartsWith("ar") -or $Locale.StartsWith("fa") -or $Locale.StartsWith("he")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$WindowsVersionTitle.Text = Get-Translation("Version")
$Continue.Content = Get-Translation("Continue")
$Back.Content = Get-Translation("Close")

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
	$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $False
	$Continue.IsEnabled = $False
	$Back.IsEnabled = $False
	Refresh-Control($Continue)
	Refresh-Control($Back)

	switch ($Stage) {

		1 { # Windows Version selection
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			Check-Locale
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
			$links = Get-Windows-Download-Links $WindowsVersion.SelectedValue.Index $ProductEdition.SelectedValue.Id $Language.SelectedValue.Id $Language.SelectedValue.Language
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
			Process-Download-Link $Architecture.SelectedValue.Link
			$script:ExitCode = 0
			$XMLForm.Close()
		}
	}
	$Continue.IsEnabled = $True
	if ($Stage -ge 0) {
		$Back.IsEnabled = $True
	}
})

$Back.add_click({
	if ($Stage -eq 0) {
		$XMLForm.Close()
	} else {
		$XMLGrid.Children.RemoveAt(2 * $Stage + 3)
		$XMLGrid.Children.RemoveAt(2 * $Stage + 2)
		$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $True
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
$XMLForm.Add_Loaded( { $XMLForm.Activate() } )
$XMLForm.ShowDialog() | Out-Null

# Clean up & exit
exit $ExitCode

# SIG # Begin signature block
# MIIm3wYJKoZIhvcNAQcCoIIm0DCCJswCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU/L412YdnIqFymsnYAgDOGvme
# DtKggiCiMIIDXzCCAkegAwIBAgILBAAAAAABIVhTCKIwDQYJKoZIhvcNAQELBQAw
# TDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0gUjMxEzARBgNVBAoTCkds
# b2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcNMDkwMzE4MTAwMDAwWhcN
# MjkwMzE4MTAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxTaWduIFJvb3QgQ0EgLSBS
# MzETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMKR2xvYmFsU2lnbjCCASIw
# DQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMwldpB5BngiFvXAg7aEyiie/QV2
# EcWtiHL8RgJDx7KKnQRfJMsuS+FggkbhUqsMgUdwbN1k0ev1LKMPgj0MK66X17YU
# hhB5uzsTgHeMCOFJ0mpiLx9e+pZo34knlTifBtc+ycsmWQ1z3rDI6SYOgxXG71uL
# 0gRgykmmKPZpO/bLyCiR5Z2KYVc3rHQU3HTgOu5yLy6c+9C7v/U9AOEGM+iCK65T
# pjoWc4zdQQ4gOsC0p6Hpsk+QLjJg6VfLuQSSaGjlOCZgdbKfd/+RFO+uIEn8rUAV
# SNECMWEZXriX7613t2Saer9fwRPvm2L7DWzgVGkWqQPabumDk3F2xmmFghcCAwEA
# AaNCMEAwDgYDVR0PAQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FI/wS3+oLkUkrk1Q+mOai97i3Ru8MA0GCSqGSIb3DQEBCwUAA4IBAQBLQNvAUKr+
# yAzv95ZURUm7lgAJQayzE4aGKAczymvmdLm6AC2upArT9fHxD4q/c2dKg8dEe3jg
# r25sbwMpjjM5RcOO5LlXbKr8EpbsU8Yt5CRsuZRj+9xTaGdWPoO4zzUhw8lo/s7a
# wlOqzJCK6fBdRoyV3XpYKBovHd7NADdBj+1EbddTKJd+82cEHhXXipa0095MJ6RM
# G3NzdvQXmcIfeg7jLQitChws/zyrVQ4PkX4268NXSb7hLi18YIvDQVETI53O9zJr
# lAGomecsMx86OyXShkDOOyyGeMlhLxS67ttVb9+E7gUJTb0o2HLO02JQZR7rkpeD
# MdmztcpHWD9fMIIFRjCCBC6gAwIBAgIQJGkmY+9sDAo7I8+jEMNkmzANBgkqhkiG
# 9w0BAQsFADB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVz
# dGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRl
# ZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0EwHhcNMTgwMzE2
# MDAwMDAwWhcNMjIwMzE2MjM1OTU5WjCBkzELMAkGA1UEBhMCSUUxETAPBgNVBBEM
# CEY5MiBENjY3MRQwEgYDVQQIDAtDby4gRG9uZWdhbDEQMA4GA1UEBwwHTWlsZm9y
# ZDEVMBMGA1UECQwMMjQgR3JleSBSb2NrMRgwFgYDVQQKDA9Ba2VvIENvbnN1bHRp
# bmcxGDAWBgNVBAMMD0FrZW8gQ29uc3VsdGluZzCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBALnCIjMLEHvLHjd7OdfWW4RX117MM7onkbZl3gfZ1ZbFNrOV
# BWd6XTUofbqQXRwdPCwtMwoqML18ZY5Sq8VRD/rMWeeABjanBnTw8ihVboJBVzi5
# laNGCNh0NR+kooOzC9tvbwHl6Dqs3tMWXwSdy+WdEq7P06/l9aTf1HI4iK09pGt8
# F4v0cP6lD8HwBKcxyzxIBk989OL329d2NhmerUeS2O4NoxVmVQeAHnh9KFaD6BxY
# 1ls4drLrW3lg1e/ODKzBL6JBRQWpUEqth3Y289MAsFr5ZyV6QMHsXS1rFLgzaooS
# vruU6gmtLOcEGvYO4+C54f4BNoE/NmabxuBVqUECAwEAAaOCAakwggGlMB8GA1Ud
# IwQYMBaAFCmRYP+KTfrr+aZquM/55ku9Sc4SMB0GA1UdDgQWBBR6pNBx16z6jH8o
# 5eK/Ub3wld+rjjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUE
# DDAKBggrBgEFBQcDAzARBglghkgBhvhCAQEEBAMCBBAwRgYDVR0gBD8wPTA7Bgwr
# BgEEAbIxAQIBAwIwKzApBggrBgEFBQcCARYdaHR0cHM6Ly9zZWN1cmUuY29tb2Rv
# Lm5ldC9DUFMwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21vZG9jYS5j
# b20vQ09NT0RPUlNBQ29kZVNpZ25pbmdDQS5jcmwwdAYIKwYBBQUHAQEEaDBmMD4G
# CCsGAQUFBzAChjJodHRwOi8vY3J0LmNvbW9kb2NhLmNvbS9DT01PRE9SU0FDb2Rl
# U2lnbmluZ0NBLmNydDAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuY29tb2RvY2Eu
# Y29tMBoGA1UdEQQTMBGBD3N1cHBvcnRAYWtlby5pZTANBgkqhkiG9w0BAQsFAAOC
# AQEAN3Ru9hbXbd/wF6MTA6L7MWrXRYIXCh45dNfvMeooLmm7Wp/S6s9srpc4+Kcd
# iglFeuFT4UcrWkteWB2QyR+0PQZU73IDaUro7N35ECnUph7PjKzTHraQE+lh9fOS
# dc/960S3Py6REnOrYqaHAJAO7j7mpRiJASTRRMKok2k40d4d8xmbNmhCSdl/A4AR
# IPc4GTVM6+s7Kax8gjgwLZjvPaMAMsCkG7v2XM7FRJjySoCeddQWZcky1uXpbwde
# 0F/eb6qIrdGRoWzExyrScaI8lGWQu2PnFehOvx20ALb3BVmuQc5Yw8kQu9LhXhD1
# fLeop3usrXffAVmhddyAfI6mEDCCBUcwggQvoAMCAQICDQHyQEJAzv0i2+lscfww
# DQYJKoZIhvcNAQEMBQAwTDEgMB4GA1UECxMXR2xvYmFsU2lnbiBSb290IENBIC0g
# UjMxEzARBgNVBAoTCkdsb2JhbFNpZ24xEzARBgNVBAMTCkdsb2JhbFNpZ24wHhcN
# MTkwMjIwMDAwMDAwWhcNMjkwMzE4MTAwMDAwWjBMMSAwHgYDVQQLExdHbG9iYWxT
# aWduIFJvb3QgQ0EgLSBSNjETMBEGA1UEChMKR2xvYmFsU2lnbjETMBEGA1UEAxMK
# R2xvYmFsU2lnbjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJUH6HPK
# ZvnsFMp7PPcNCPG0RQssgrRIxutbPK6DuEGSMxSkb3/pKszGsIhrxbaJ0cay/xTO
# URQh7ErdG1rG1ofuTToVBu1kZguSgMpE3nOUTvOniX9PeGMIyBJQbUJmL025eShN
# UhqKGoC3GYEOfsSKvGRMIRxDaNc9PIrFsmbVkJq3MQbFvuJtMgamHvm566qjuL++
# gmNQ0PAYid/kD3n16qIfKtJwLnvnvJO7bVPiSHyMEAc4/2ayd2F+4OqMPKq0pPbz
# lUoSB239jLKJz9CgYXfIWHSw1CM69106yqLbnQneXUQtkPGBzVeS+n68UARjNN9r
# kxi+azayOeSsJDa38O+2HBNXk7besvjihbdzorg1qkXy4J02oW9UivFyVm4uiMVR
# QkQVlO6jxTiWm05OWgtH8wY2SXcwvHE35absIQh1/OZhFj931dmRl4QKbNQCTXTA
# FO39OfuD8l4UoQSwC+n+7o/hbguyCLNhZglqsQY6ZZZZwPA1/cnaKI0aEYdwgQqo
# mnUdnjqGBQCe24DWJfncBZ4nWUx2OVvq+aWh2IMP0f/fMBH5hc8zSPXKbWQULHpY
# T9NLCEnFlWQaYw55PfWzjMpYrZxCRXluDocZXFSxZba/jJvcE+kNb7gu3GduyYsR
# tYQUigAZcIN5kZeR1BonvzceMgfYFGM8KEyvAgMBAAGjggEmMIIBIjAOBgNVHQ8B
# Af8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUrmwFo5MT4qLn4tcc
# 1sfwf8hnU6AwHwYDVR0jBBgwFoAUj/BLf6guRSSuTVD6Y5qL3uLdG7wwPgYIKwYB
# BQUHAQEEMjAwMC4GCCsGAQUFBzABhiJodHRwOi8vb2NzcDIuZ2xvYmFsc2lnbi5j
# b20vcm9vdHIzMDYGA1UdHwQvMC0wK6ApoCeGJWh0dHA6Ly9jcmwuZ2xvYmFsc2ln
# bi5jb20vcm9vdC1yMy5jcmwwRwYDVR0gBEAwPjA8BgRVHSAAMDQwMgYIKwYBBQUH
# AgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24uY29tL3JlcG9zaXRvcnkvMA0GCSqG
# SIb3DQEBDAUAA4IBAQBJrF7Fg/Nay2EqTZdKFSmf5BSQqgn5xHqfNRiKCjMVbXKH
# Ik5BP20Knhiu2+Jf/JXRLJgUO47B8DZZefONgc909hik5OFoz+9/ZVlC6cpVObzT
# xSbucTj61yEDD7dO2VtgakO0fQnQYGHdqu0AXk4yHuCybJ48ssK7mNOQdmpprRrc
# qInaWE/SwosySs5U+zjpOwcLdQoR2wt8JSfxrCbPEVPm3MbiYTUy9M7dg+MZOuvC
# aKNyAMgkPE64UzyxF6vmNSz500Ip5l9gA6xCYaaxV2ozQt81MYbKPjcr2sTaJPVO
# EvK2ubdH6rsgrWEWt6Az4y2Jp7yzPAF/IxqACTTpMIIF4DCCA8igAwIBAgIQLnyH
# zA6TSlL+lP0ct800rzANBgkqhkiG9w0BAQwFADCBhTELMAkGA1UEBhMCR0IxGzAZ
# BgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEaMBgG
# A1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBSU0EgQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTMwNTA5MDAwMDAwWhcNMjgwNTA4MjM1
# OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEj
# MCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0EwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCmmJBjd5E0f4rR3elnMRHrzB79MR2zuWJXP5O8
# W+OfHiQyESdrvFGRp8+eniWzX4GoGA8dHiAwDvthe4YJs+P9omidHCydv3Lj5HWg
# 5TUjjsmK7hoMZMfYQqF7tVIDSzqwjiNLS2PgIpQ3e9V5kAoUGFEs5v7BEvAcP2Fh
# Coyi3PbDMKrNKBh1SMF5WgjNu4xVjPfUdpA6M0ZQc5hc9IVKaw+A3V7Wvf2pL8Al
# 9fl4141fEMJEVTyQPDFGy3CuB6kK46/BAW+QGiPiXzjbxghdR7ODQfAuADcUuRKq
# eZJSzYcPe9hiKaR+ML0btYxytEjy4+gh+V5MYnmLAgaff9ULAgMBAAGjggFRMIIB
# TTAfBgNVHSMEGDAWgBS7r34CPfqm8TyEjq3uOJjs2TIy1DAdBgNVHQ4EFgQUKZFg
# /4pN+uv5pmq4z/nmS71JzhIwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYDVR0gBAowCDAGBgRVHSAAMEwG
# A1UdHwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NPTU9ET1JT
# QUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHEGCCsGAQUFBwEBBGUwYzA7Bggr
# BgEFBQcwAoYvaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNBQWRkVHJ1
# c3RDQS5jcnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2NhLmNvbTAN
# BgkqhkiG9w0BAQwFAAOCAgEAAj8COcPu+Mo7id4MbU2x8U6ST6/COCwEzMVjEasJ
# Y6+rotcCP8xvGcM91hoIlP8l2KmIpysQGuCbsQciGlEcOtTh6Qm/5iR0rx57FjFu
# I+9UUS1SAuJ1CAVM8bdR4VEAxof2bO4QRHZXavHfWGshqknUfDdOvf+2dVRAGDZX
# ZxHNTwLk/vPa/HUX2+y392UJI0kfQ1eD6n4gd2HITfK7ZU2o94VFB696aSdlkClA
# i997OlE5jKgfcHmtbUIgos8MbAOMTM1zB5TnWo46BLqioXwfy2M6FafUFRunUkcy
# qfS/ZEfRqh9TTjIwc8Jvt3iCnVz/RrtrIh2IC/gbqjSm/Iz13X9ljIwxVzHQNuxH
# oc/Li6jvHBhYxQZ3ykubUa9MCEp6j+KjUuKOjswm5LLY5TjCqO3GgZw1a6lYYUoK
# l7RLQrZVnb6Z53BtWfhtKgx/GWBfDJqIbDCsUgmQFhv/K53b0CDKieoofjKOGd97
# SDMe12X4rsn4gxSTdn1k0I7OvjV9/3IxTZ+evR5sL6iPDAZQ+4wns3bJ9ObXwzTi
# jIchhmH+v1V04SF3AwpobLvkyanmz1kl63zsRQ55ZmjoIs2475iFTZYRPAmK0H+8
# KCgT+2rKVI2SXM3CZZgGns5IW9S1N5NGQXwH3c/6Q++6Z2H/fUnguzB9XIDj5hY5
# S6cwggZZMIIEQaADAgECAg0B7BySQN79LkBdfEd0MA0GCSqGSIb3DQEBDAUAMEwx
# IDAeBgNVBAsTF0dsb2JhbFNpZ24gUm9vdCBDQSAtIFI2MRMwEQYDVQQKEwpHbG9i
# YWxTaWduMRMwEQYDVQQDEwpHbG9iYWxTaWduMB4XDTE4MDYyMDAwMDAwMFoXDTM0
# MTIxMDAwMDAwMFowWzELMAkGA1UEBhMCQkUxGTAXBgNVBAoTEEdsb2JhbFNpZ24g
# bnYtc2ExMTAvBgNVBAMTKEdsb2JhbFNpZ24gVGltZXN0YW1waW5nIENBIC0gU0hB
# Mzg0IC0gRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDwAuIwI/rg
# G+GadLOvdYNfqUdSx2E6Y3w5I3ltdPwx5HQSGZb6zidiW64HiifuV6PENe2zNMes
# wwzrgGZt0ShKwSy7uXDycq6M95laXXauv0SofEEkjo+6xU//NkGrpy39eE5DiP6T
# GRfZ7jHPvIo7bmrEiPDul/bc8xigS5kcDoenJuGIyaDlmeKe9JxMP11b7Lbv0mXP
# RQtUPbFUUweLmW64VJmKqDGSO/J6ffwOWN+BauGwbB5lgirUIceU/kKWO/ELsX9/
# RpgOhz16ZevRVqkuvftYPbWF+lOZTVt07XJLog2CNxkM0KvqWsHvD9WZuT/0TzXx
# nA/TNxNS2SU07Zbv+GfqCL6PSXr/kLHU9ykV1/kNXdaHQx50xHAotIB7vSqbu4Th
# DqxvDbm19m1W/oodCT4kDmcmx/yyDaCUsLKUzHvmZ/6mWLLU2EESwVX9bpHFu7FM
# CEue1EIGbxsY1TbqZK7O/fUF5uJm0A4FIayxEQYjGeT7BTRE6giunUlnEYuC5a1a
# hqdm/TMDAd6ZJflxbumcXQJMYDzPAo8B/XLukvGnEt5CEk3sqSbldwKsDlcMCdFh
# niaI/MiyTdtk8EWfusE/VKPYdgKVbGqNyiJc9gwE4yn6S7Ac0zd0hNkdZqs0c48e
# fXxeltY9GbCX6oxQkW2vV4Z+EDcdaxoU3wIDAQABo4IBKTCCASUwDgYDVR0PAQH/
# BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFOoWxmnn48tXRTkz
# pPBAvtDDvWWWMB8GA1UdIwQYMBaAFK5sBaOTE+Ki5+LXHNbH8H/IZ1OgMD4GCCsG
# AQUFBwEBBDIwMDAuBggrBgEFBQcwAYYiaHR0cDovL29jc3AyLmdsb2JhbHNpZ24u
# Y29tL3Jvb3RyNjA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vY3JsLmdsb2JhbHNp
# Z24uY29tL3Jvb3QtcjYuY3JsMEcGA1UdIARAMD4wPAYEVR0gADA0MDIGCCsGAQUF
# BwIBFiZodHRwczovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzANBgkq
# hkiG9w0BAQwFAAOCAgEAf+KI2VdnK0JfgacJC7rEuygYVtZMv9sbB3DG+wsJrQA6
# YDMfOcYWaxlASSUIHuSb99akDY8elvKGohfeQb9P4byrze7AI4zGhf5LFST5GETs
# H8KkrNCyz+zCVmUdvX/23oLIt59h07VGSJiXAmd6FpVK22LG0LMCzDRIRVXd7OlK
# n14U7XIQcXZw0g+W8+o3V5SRGK/cjZk4GVjCqaF+om4VJuq0+X8q5+dIZGkv0pqh
# cvb3JEt0Wn1yhjWzAlcfi5z8u6xM3vreU0yD/RKxtklVT3WdrG9KyC5qucqIwxIw
# TrIIc59eodaZzul9S5YszBZrGM3kWTeGCSziRdayzW6CdaXajR63Wy+ILj198fKR
# MAWcznt8oMWsr1EG8BHHHTDFUVZg6HyVPSLj1QokUyeXgPpIiScseeI85Zse46qE
# gok+wEr1If5iEO0dMPz2zOpIJ3yLdUJ/a8vzpWuVHwRYNAqJ7YJQ5NF7qMnmvkiq
# K1XZjbclIA4bUaDUY6qD6mxyYUrJ+kPExlfFnbY8sIuwuRwx773vFNgUQGwgHcIt
# 6AvGjW2MtnHtUiH+PvafnzkarqzSL3ogsfSsqh3iLRSd+pZqHcY8yvPZHL9TTaRH
# WXyVxENB+SXiLBB+gfkNlKd98rUJ9dhgckBQlSDUQ0S++qCV5yBZtnjGpGqqIpsw
# ggZlMIIETaADAgECAhABhNOozjeB61f0/Yd7g66yMA0GCSqGSIb3DQEBCwUAMFsx
# CzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQD
# EyhHbG9iYWxTaWduIFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0MB4XDTIx
# MDUyNzEwMDAxNloXDTMyMDYyODEwMDAxNVowYzELMAkGA1UEBhMCQkUxGTAXBgNV
# BAoMEEdsb2JhbFNpZ24gbnYtc2ExOTA3BgNVBAMMMEdsb2JhbHNpZ24gVFNBIGZv
# ciBNUyBBdXRoZW50aWNvZGUgQWR2YW5jZWQgLSBHNDCCAaIwDQYJKoZIhvcNAQEB
# BQADggGPADCCAYoCggGBAOKim7ZJ+zRIKCMHhv1SE026y6o14vlAHBt7acWYKszJ
# XO8nxuy4JWXDPx1E597hCO8EFwCVlwz9212DtIjroI6bT4O6+d9eGFRqAg4O5lTw
# N6QenGcxBbU3cXx6ftiBZTPkmuqwMTfHZrSjugUn6m5SgljZglYkjfnrsxT7ZACh
# eyofep6oY5Hm2NEixj/SnTg/r5VpWye/6EAkmccf2XuSBQJ9KMY8Ofd6zfdlJqA3
# rzIFd5dq4RAbmIUshK3lJYZ8c57NiI1LKnqdD1l5vfLaNn5mrC74u4iXyW158rPU
# 1cwa9E+LRZV28oeVgI4oebr9xXCvvBoUApB8JlsRi131uuQRAsWBHGZoS95ozp0M
# iGGqtpQjneCkPEZdBFHbP1kL5+y+0tkTKkfvSxISbsg1z+4WMrbQX4W4T/J82Akr
# El7Awu8TMXA2c9zWV1TTV2CeHBCV8OaqLxCKG37JzY/OUEscJajAF2RRFQuMz9fJ
# XUpsSXSuWvFqBnU+iTc7kQIDAQABo4IBmzCCAZcwDgYDVR0PAQH/BAQDAgeAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMB0GA1UdDgQWBBR1ryc/uNua7G8c7sNqZPa/
# hDWwzjBMBgNVHSAERTBDMEEGCSsGAQQBoDIBHjA0MDIGCCsGAQUFBwIBFiZodHRw
# czovL3d3dy5nbG9iYWxzaWduLmNvbS9yZXBvc2l0b3J5LzAJBgNVHRMEAjAAMIGQ
# BggrBgEFBQcBAQSBgzCBgDA5BggrBgEFBQcwAYYtaHR0cDovL29jc3AuZ2xvYmFs
# c2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0MEMGCCsGAQUFBzAChjdodHRwOi8v
# c2VjdXJlLmdsb2JhbHNpZ24uY29tL2NhY2VydC9nc3RzYWNhc2hhMzg0ZzQuY3J0
# MB8GA1UdIwQYMBaAFOoWxmnn48tXRTkzpPBAvtDDvWWWMEEGA1UdHwQ6MDgwNqA0
# oDKGMGh0dHA6Ly9jcmwuZ2xvYmFsc2lnbi5jb20vY2EvZ3N0c2FjYXNoYTM4NGc0
# LmNybDANBgkqhkiG9w0BAQsFAAOCAgEAOJO3fTWJNOoa1qp6zo2E2+E0t3Sl/9hd
# lDYlj9KAfqFlsZvPNVFd26BLbvchQC7sT28WQHIcdRswABc5j8gvpHHOJDMmkNXk
# /zm5Ye8LyjnzLV6NoP9O4VZkH9ScdgSkRFw9YoVwL/lOpPeGVtt6SSZDLQWb4sOJ
# tzqhLScnGMZDi9xDobZyLT/ZxjSKAtNiOSnwfSjQqcNkikZts0McdIvduaYLIXsR
# px9dotuM4FXTafp30V0UuZbskUUbG2x+QkAkpO1AxmX6QY9IMZzjuLMXV4J5yswe
# wtBPTwUODXnXad2VoXFdip7nWsJPqAYPCIl721jIJX3/aLwoonCcuwy1U+iOBrGy
# goGHEqled0yTqxj4RFdYEcv2kxVJMbdTUCHa1fxgf90wxaxRRAtnpfrWdzStEh8o
# +4jaUZtEmt53Du4yEmBWDJGdWI+8mVfyvs25w3MkGdp3puTs8d5v4LyEHW/D8dvh
# 1UJRhlESQiY+0+oT9CicrU16t6K6FGo/QFVYToxlHLP2ddZ/rg+EgC++iHhcJx9H
# F8I95Gmey66e7wJoiDcQwmwmisiMZZBTTa5d2rhGENSQCor/9ChAgeBSyPIBZEgY
# hHhqIvrKnKoOHcWOcsM2Ihnr+JQfv8LFAVbppoDqAR0TNQfiuXQU/Zo4ngPSSfZM
# 66G9HBTS45kxggWnMIIFowIBATCBkTB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFD
# T01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25p
# bmcgQ0ECECRpJmPvbAwKOyPPoxDDZJswCQYFKw4DAhoFAKB4MBgGCisGAQQBgjcC
# AQwxCjAIoAKAAKECgAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYB
# BAGCNwIBCzEOMAwGCisGAQQBgjcCARUwIwYJKoZIhvcNAQkEMRYEFNjCGFk20sPC
# Cpi9ZluvDPRcbQNiMA0GCSqGSIb3DQEBAQUABIIBALeyMVfNZvv8ADrtW/SWGXi9
# 30lhtesUfS+9TWT9d6AIuv9ooJI2itDBwcPBHy4iV3gnIV+sEbJQN3319fcYP7Er
# aUTU3MmGpFvNiuU5IUuMAVSGZz8fgwjHdifFLghBb6dELltlYdX23u/tz5S+o4RX
# 7LZrRa7eRcu3sAYAG6O4z1AnhzHg/Z68re0gGGC2zv4g9nQrPLsTNscaULChxcA9
# dLrJwbIZuZCvWivy26HRzVUrxiY8nK4WDIErHDQ3jl36ycyIBb+hdl61PCWLDKPs
# 0PUt5hI4IIKdL4CWGREz26vgaIZssZcTZdWZLX1xKwc54FhrSezJPwW2Ae8WC4yh
# ggNwMIIDbAYJKoZIhvcNAQkGMYIDXTCCA1kCAQEwbzBbMQswCQYDVQQGEwJCRTEZ
# MBcGA1UEChMQR2xvYmFsU2lnbiBudi1zYTExMC8GA1UEAxMoR2xvYmFsU2lnbiBU
# aW1lc3RhbXBpbmcgQ0EgLSBTSEEzODQgLSBHNAIQAYTTqM43getX9P2He4OusjAN
# BglghkgBZQMEAgEFAKCCAT8wGAYJKoZIhvcNAQkDMQsGCSqGSIb3DQEHATAcBgkq
# hkiG9w0BCQUxDxcNMjEwODA3MjEzMDMxWjAtBgkqhkiG9w0BCTQxIDAeMA0GCWCG
# SAFlAwQCAQUAoQ0GCSqGSIb3DQEBCwUAMC8GCSqGSIb3DQEJBDEiBCCcvqCWuD80
# KNl9ZWmLr4VnwtUXdbgMURXSuFa/UXlNfDCBpAYLKoZIhvcNAQkQAgwxgZQwgZEw
# gY4wgYsEFN1XtbOHPIYbKcauxHMa++iNdcFJMHMwX6RdMFsxCzAJBgNVBAYTAkJF
# MRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTEwLwYDVQQDEyhHbG9iYWxTaWdu
# IFRpbWVzdGFtcGluZyBDQSAtIFNIQTM4NCAtIEc0AhABhNOozjeB61f0/Yd7g66y
# MA0GCSqGSIb3DQEBCwUABIIBgL0I1stv/LKS2eWaUOkrWDchIY1XL2wQQLyu+F/w
# 43dFR16c1rzL2SwyiQx85whTxivm24WJQFWyAtEFUqrXfboL0WW6RoFtgIKi0PEX
# ecpdrD2ECiGnGnVrgHMoyB0t7m9WzwItEpGMgmiLfqWP63tv3/foVFC5/0rn0D65
# EOm5BEgOvsvJgPb+RtFHgzPGU7Srj+OqJmiRjxy+CzZee3hKHCWzwB09jd0XhVCT
# hb1ycICO3lKkiTFtXXh02o35jm7YQaC53ibMnCeWrIyHfx/PNWFFKARpLMndwrkY
# cVZDLmMOKYKdyD9nUWNZ/hDCJOh856e0xJNJ0Ov39Edl8SF6P4ghR3nYQqN5zbWV
# y2Ee6Aaifjej/M9/UoqNJELXtojy+YWUVmK0CFAAGEzyar2o5n4/dPaeu0f+7/AV
# 5H+HdRMoxmllQrmSVY9A7Bz/xlE4qxchhxfUP+kEbs6uz0AqpDVQj9B2fwFDYLs0
# Kzy+fokB/NwBSYEWoRMPc8oRSg==
# SIG # End signature block
