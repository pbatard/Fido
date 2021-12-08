#
# Fido v1.27 - Feature ISO Downloader, for retail Windows images and UEFI Shell
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
		@("Windows 11", "windows11"),
		@(
			"21H2 (Build 22000.194 - 2021.10)",
			@("Windows 11 Home/Pro/Edu", 2069),
			@("Windows 11 Home China ", ($zh + 2070))
		)
	),
	@(
		@("Windows 10", "Windows10ISO"),
		@(
			"21H2 (Build 19044.1288 - 2021.11)",
			@("Windows 10 Home/Pro/Edu", 2084),
			@("Windows 10 Home China ", ($zh + 2085))
		),
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
			"1809 R3 (Build 17763.379 - 2019.03)",
			@("Windows 10 Home/Pro", 1203),
			@("Windows 10 Education", 1202),
			@("Windows 10 Home China ", ($zh + 1204))
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
	),
	@(
		@("UEFI Shell 2.2", "UEFI_SHELL 2.2"),
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
function Check-Locale {
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

			# Build a hashtable out of all ISO hashes in response
			$hashPattern = '(?s)(<td>.*?</td>)'
			$hashesHashtable = @{}
			ForEach-Object { [regex]::Matches($r, $hashPattern) } | ForEach-Object -End $Null -Begin { $index = 0; $key=''; } -Process {
				$value = $_.Groups[1].Value -replace '<td>', ''
				$value = $value -replace '</td>', ''

				# If index is even number, it's a key (language and arch), if odd, it's the hash for the corresponding ISO
				If ($index % 2 -eq 0) {
					$key = $value
				} Else {
					$hashesHashtable.Add($key, $value)
				}
				$index++
			}

			foreach ($var in $xml.inputs.input) {
				$json = $var.value | ConvertFrom-Json;
				if ($json) {
					$json | ForEach-Object {
						If ($_.DownloadType -eq 'x64') {
							$isoArchType = '64-bit'
						} Else {
							$isoArchType = '32-bit'
						}

						$_ | Add-Member -NotePropertyName 'FileHash' -NotePropertyValue $hashesHashtable["$($_.Language)  $isoArchType"]
					}
					if (($Is64 -and $json.DownloadType -eq "x64") -or (-not $Is64 -and $json.DownloadType -eq "x86")) {
						$script:SelectedIndex = $i
					}
					$links += @(New-Object PsObject -Property @{ Type = $json.DownloadType; Link = $json.Uri; FileHash = $json.FileHash })
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
		if ($PipeName -and -not $Check.IsChecked) {
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
				Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $File
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
		Return $winLink
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
			if ($WindowsVersion.SelectedValue.Version.StartsWith("Windows") -and $WindowsVersion.SelectedValue.Version -ne "Windows 7") {
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
# MIIcUwYJKoZIhvcNAQcCoIIcRDCCHEACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAF0UXsqZmeL25A
# MSWoPbcY29KPjzQzrJCqS4GLpRVOMqCCCy4wggVGMIIELqADAgECAhAkaSZj72wM
# Cjsjz6MQw2SbMA0GCSqGSIb3DQEBCwUAMH0xCzAJBgNVBAYTAkdCMRswGQYDVQQI
# ExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1NhbGZvcmQxGjAYBgNVBAoT
# EUNPTU9ETyBDQSBMaW1pdGVkMSMwIQYDVQQDExpDT01PRE8gUlNBIENvZGUgU2ln
# bmluZyBDQTAeFw0xODAzMTYwMDAwMDBaFw0yMjAzMTYyMzU5NTlaMIGTMQswCQYD
# VQQGEwJJRTERMA8GA1UEEQwIRjkyIEQ2NjcxFDASBgNVBAgMC0NvLiBEb25lZ2Fs
# MRAwDgYDVQQHDAdNaWxmb3JkMRUwEwYDVQQJDAwyNCBHcmV5IFJvY2sxGDAWBgNV
# BAoMD0FrZW8gQ29uc3VsdGluZzEYMBYGA1UEAwwPQWtlbyBDb25zdWx0aW5nMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAucIiMwsQe8seN3s519ZbhFfX
# XswzuieRtmXeB9nVlsU2s5UFZ3pdNSh9upBdHB08LC0zCiowvXxljlKrxVEP+sxZ
# 54AGNqcGdPDyKFVugkFXOLmVo0YI2HQ1H6Sig7ML229vAeXoOqze0xZfBJ3L5Z0S
# rs/Tr+X1pN/UcjiIrT2ka3wXi/Rw/qUPwfAEpzHLPEgGT3z04vfb13Y2GZ6tR5LY
# 7g2jFWZVB4AeeH0oVoPoHFjWWzh2sutbeWDV784MrMEvokFFBalQSq2Hdjbz0wCw
# WvlnJXpAwexdLWsUuDNqihK+u5TqCa0s5wQa9g7j4Lnh/gE2gT82ZpvG4FWpQQID
# AQABo4IBqTCCAaUwHwYDVR0jBBgwFoAUKZFg/4pN+uv5pmq4z/nmS71JzhIwHQYD
# VR0OBBYEFHqk0HHXrPqMfyjl4r9RvfCV36uOMA4GA1UdDwEB/wQEAwIHgDAMBgNV
# HRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMBEGCWCGSAGG+EIBAQQEAwIE
# EDBGBgNVHSAEPzA9MDsGDCsGAQQBsjEBAgEDAjArMCkGCCsGAQUFBwIBFh1odHRw
# czovL3NlY3VyZS5jb21vZG8ubmV0L0NQUzBDBgNVHR8EPDA6MDigNqA0hjJodHRw
# Oi8vY3JsLmNvbW9kb2NhLmNvbS9DT01PRE9SU0FDb2RlU2lnbmluZ0NBLmNybDB0
# BggrBgEFBQcBAQRoMGYwPgYIKwYBBQUHMAKGMmh0dHA6Ly9jcnQuY29tb2RvY2Eu
# Y29tL0NPTU9ET1JTQUNvZGVTaWduaW5nQ0EuY3J0MCQGCCsGAQUFBzABhhhodHRw
# Oi8vb2NzcC5jb21vZG9jYS5jb20wGgYDVR0RBBMwEYEPc3VwcG9ydEBha2VvLmll
# MA0GCSqGSIb3DQEBCwUAA4IBAQA3dG72Ftdt3/AXoxMDovsxatdFghcKHjl01+8x
# 6iguabtan9Lqz2yulzj4px2KCUV64VPhRytaS15YHZDJH7Q9BlTvcgNpSujs3fkQ
# KdSmHs+MrNMetpAT6WH185J1z/3rRLc/LpESc6tipocAkA7uPualGIkBJNFEwqiT
# aTjR3h3zGZs2aEJJ2X8DgBEg9zgZNUzr6zsprHyCODAtmO89owAywKQbu/ZczsVE
# mPJKgJ511BZlyTLW5elvB17QX95vqoit0ZGhbMTHKtJxojyUZZC7Y+cV6E6/HbQA
# tvcFWa5BzljDyRC70uFeEPV8t6ine6ytd98BWaF13IB8jqYQMIIF4DCCA8igAwIB
# AgIQLnyHzA6TSlL+lP0ct800rzANBgkqhkiG9w0BAQwFADCBhTELMAkGA1UEBhMC
# R0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9y
# ZDEaMBgGA1UEChMRQ09NT0RPIENBIExpbWl0ZWQxKzApBgNVBAMTIkNPTU9ETyBS
# U0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTMwNTA5MDAwMDAwWhcNMjgw
# NTA4MjM1OTU5WjB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5j
# aGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGlt
# aXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25pbmcgQ0EwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCmmJBjd5E0f4rR3elnMRHrzB79MR2z
# uWJXP5O8W+OfHiQyESdrvFGRp8+eniWzX4GoGA8dHiAwDvthe4YJs+P9omidHCyd
# v3Lj5HWg5TUjjsmK7hoMZMfYQqF7tVIDSzqwjiNLS2PgIpQ3e9V5kAoUGFEs5v7B
# EvAcP2FhCoyi3PbDMKrNKBh1SMF5WgjNu4xVjPfUdpA6M0ZQc5hc9IVKaw+A3V7W
# vf2pL8Al9fl4141fEMJEVTyQPDFGy3CuB6kK46/BAW+QGiPiXzjbxghdR7ODQfAu
# ADcUuRKqeZJSzYcPe9hiKaR+ML0btYxytEjy4+gh+V5MYnmLAgaff9ULAgMBAAGj
# ggFRMIIBTTAfBgNVHSMEGDAWgBS7r34CPfqm8TyEjq3uOJjs2TIy1DAdBgNVHQ4E
# FgQUKZFg/4pN+uv5pmq4z/nmS71JzhIwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB
# /wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwEQYDVR0gBAowCDAGBgRV
# HSAAMEwGA1UdHwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuY29tb2RvY2EuY29tL0NP
# TU9ET1JTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMHEGCCsGAQUFBwEBBGUw
# YzA7BggrBgEFBQcwAoYvaHR0cDovL2NydC5jb21vZG9jYS5jb20vQ09NT0RPUlNB
# QWRkVHJ1c3RDQS5jcnQwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmNvbW9kb2Nh
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAAj8COcPu+Mo7id4MbU2x8U6ST6/COCwE
# zMVjEasJY6+rotcCP8xvGcM91hoIlP8l2KmIpysQGuCbsQciGlEcOtTh6Qm/5iR0
# rx57FjFuI+9UUS1SAuJ1CAVM8bdR4VEAxof2bO4QRHZXavHfWGshqknUfDdOvf+2
# dVRAGDZXZxHNTwLk/vPa/HUX2+y392UJI0kfQ1eD6n4gd2HITfK7ZU2o94VFB696
# aSdlkClAi997OlE5jKgfcHmtbUIgos8MbAOMTM1zB5TnWo46BLqioXwfy2M6FafU
# FRunUkcyqfS/ZEfRqh9TTjIwc8Jvt3iCnVz/RrtrIh2IC/gbqjSm/Iz13X9ljIwx
# VzHQNuxHoc/Li6jvHBhYxQZ3ykubUa9MCEp6j+KjUuKOjswm5LLY5TjCqO3GgZw1
# a6lYYUoKl7RLQrZVnb6Z53BtWfhtKgx/GWBfDJqIbDCsUgmQFhv/K53b0CDKieoo
# fjKOGd97SDMe12X4rsn4gxSTdn1k0I7OvjV9/3IxTZ+evR5sL6iPDAZQ+4wns3bJ
# 9ObXwzTijIchhmH+v1V04SF3AwpobLvkyanmz1kl63zsRQ55ZmjoIs2475iFTZYR
# PAmK0H+8KCgT+2rKVI2SXM3CZZgGns5IW9S1N5NGQXwH3c/6Q++6Z2H/fUnguzB9
# XIDj5hY5S6cxghB7MIIQdwIBATCBkTB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFD
# T01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25p
# bmcgQ0ECECRpJmPvbAwKOyPPoxDDZJswDQYJYIZIAWUDBAIBBQCgfDAQBgorBgEE
# AYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg+CKeEEG6VBPas6x2
# A1VqtseZCpA1ZhZ8VbWjABLaSCcwDQYJKoZIhvcNAQEBBQAEggEAfYZZQvCHsgPy
# y0bl8QSVcTjgVxtEL5lmYEfRn65zHfYYHJoTK6hGLYtkVywIRqcwDF+yDpGr6UMK
# LqsKCNQLHE8mcVL6E9w2j3iGPgGaH27wLXOVVYJb2G5k8CkLEUUaLq9lNUTqVo07
# 5KBHq35U5GmyqxrTfMoMybkym/fZ2PNr5Uov3RAR4PcJzvLhUqvfxZ7ETEcUrWIs
# AhQwMJJKG7RNuXukfeQJW3YZWLjT6EtvCqykrrIXOwzhoIGXf4yWjTGaPHcSqYtY
# 0EcvEWqwq63y21suyvXxEAIwKRMf0WB9MCg1pYRBqFONvZpi6kaj+pc1JHNG8qrn
# +cdem7C3DKGCDjwwgg44BgorBgEEAYI3AwMBMYIOKDCCDiQGCSqGSIb3DQEHAqCC
# DhUwgg4RAgEDMQ0wCwYJYIZIAWUDBAIBMIIBDgYLKoZIhvcNAQkQAQSggf4Egfsw
# gfgCAQEGC2CGSAGG+EUBBxcDMDEwDQYJYIZIAWUDBAIBBQAEIGrZO72RyxWhbJuN
# Hx+96YDnnAxKZhYyMX/oub0TD4Z3AhRZR6prTJiWjABdWqtIx9I1LN31pBgPMjAy
# MTExMTYyMTAzMjRaMAMCAR6ggYakgYMwgYAxCzAJBgNVBAYTAlVTMR0wGwYDVQQK
# ExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3Qg
# TmV0d29yazExMC8GA1UEAxMoU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFtcGluZyBT
# aWduZXIgLSBHM6CCCoswggU4MIIEIKADAgECAhB7BbHUSWhRRPfJidKcGZ0SMA0G
# CSqGSIb3DQEBCwUAMIG9MQswCQYDVQQGEwJVUzEXMBUGA1UEChMOVmVyaVNpZ24s
# IEluYy4xHzAdBgNVBAsTFlZlcmlTaWduIFRydXN0IE5ldHdvcmsxOjA4BgNVBAsT
# MShjKSAyMDA4IFZlcmlTaWduLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9u
# bHkxODA2BgNVBAMTL1ZlcmlTaWduIFVuaXZlcnNhbCBSb290IENlcnRpZmljYXRp
# b24gQXV0aG9yaXR5MB4XDTE2MDExMjAwMDAwMFoXDTMxMDExMTIzNTk1OVowdzEL
# MAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMR8wHQYD
# VQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMSgwJgYDVQQDEx9TeW1hbnRlYyBT
# SEEyNTYgVGltZVN0YW1waW5nIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAu1mdWVVPnYxyXRqBoutV87ABrTxxrDKPBWuGmicAMpdqTclkFEspu8LZ
# Kbku7GOz4c8/C1aQ+GIbfuumB+Lef15tQDjUkQbnQXx5HMvLrRu/2JWR8/DubPit
# ljkuf8EnuHg5xYSl7e2vh47Ojcdt6tKYtTofHjmdw/SaqPSE4cTRfHHGBim0P+SD
# DSbDewg+TfkKtzNJ/8o71PWym0vhiJka9cDpMxTW38eA25Hu/rySV3J39M2ozP4J
# 9ZM3vpWIasXc9LFL1M7oCZFftYR5NYp4rBkyjyPBMkEbWQ6pPrHM+dYr77fY5NUd
# bRE6kvaTyZzjSO67Uw7UNpeGeMWhNwIDAQABo4IBdzCCAXMwDgYDVR0PAQH/BAQD
# AgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAwZgYDVR0gBF8wXTBbBgtghkgBhvhFAQcX
# AzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2IuY29tL2NwczAlBggrBgEF
# BQcCAjAZGhdodHRwczovL2Quc3ltY2IuY29tL3JwYTAuBggrBgEFBQcBAQQiMCAw
# HgYIKwYBBQUHMAGGEmh0dHA6Ly9zLnN5bWNkLmNvbTA2BgNVHR8ELzAtMCugKaAn
# hiVodHRwOi8vcy5zeW1jYi5jb20vdW5pdmVyc2FsLXJvb3QuY3JsMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1lU3RhbXAt
# MjA0OC0zMB0GA1UdDgQWBBSvY9bKo06FcuCnvEHzKaI4f4B1YjAfBgNVHSMEGDAW
# gBS2d/ppSEefUxLVwuoHMnYH0ZcHGTANBgkqhkiG9w0BAQsFAAOCAQEAdeqwLdU0
# GVwyRf4O4dRPpnjBb9fq3dxP86HIgYj3p48V5kApreZd9KLZVmSEcTAq3R5hF2Yg
# VgaYGY1dcfL4l7wJ/RyRR8ni6I0D+8yQL9YKbE4z7Na0k8hMkGNIOUAhxN3WbomY
# PLWYl+ipBrcJyY9TV0GQL+EeTU7cyhB4bEJu8LbF+GFcUvVO9muN90p6vvPN/QPX
# 2fYDqA/jU/cKdezGdS6qZoUEmbf4Blfhxg726K/a7JsYH6q54zoAv86KlMsB257H
# OLsPUqvR45QDYApNoP4nbRQy/D+XQOG/mYnb5DkUvdrk08PqK1qzlVhVBH3Hmuwj
# A42FKtL/rqlhgTCCBUswggQzoAMCAQICEHvU5a+6zAc/oQEjBCJBTRIwDQYJKoZI
# hvcNAQELBQAwdzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBv
# cmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3b3JrMSgwJgYDVQQD
# Ex9TeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIENBMB4XDTE3MTIyMzAwMDAw
# MFoXDTI5MDMyMjIzNTk1OVowgYAxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1h
# bnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29y
# azExMC8GA1UEAxMoU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFtcGluZyBTaWduZXIg
# LSBHMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAK8Oiqr43L9pe1QX
# cUcJvY08gfh0FXdnkJz93k4Cnkt29uU2PmXVJCBtMPndHYPpPydKM05tForkjUCN
# Iqq+pwsb0ge2PLUaJCj4G3JRPcgJiCYIOvn6QyN1R3AMs19bjwgdckhXZU2vAjxA
# 9/TdMjiTP+UspvNZI8uA3hNN+RDJqgoYbFVhV9HxAizEtavybCPSnw0PGWythWJp
# /U6FwYpSMatb2Ml0UuNXbCK/VX9vygarP0q3InZl7Ow28paVgSYs/buYqgE4068l
# QJsJU/ApV4VYXuqFSEEhh+XetNMmsntAU1h5jlIxBk2UA0XEzjwD7LcA8joixbRv
# 5e+wipsCAwEAAaOCAccwggHDMAwGA1UdEwEB/wQCMAAwZgYDVR0gBF8wXTBbBgtg
# hkgBhvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczovL2Quc3ltY2IuY29tL2Nw
# czAlBggrBgEFBQcCAjAZGhdodHRwczovL2Quc3ltY2IuY29tL3JwYTBABgNVHR8E
# OTA3MDWgM6Axhi9odHRwOi8vdHMtY3JsLndzLnN5bWFudGVjLmNvbS9zaGEyNTYt
# dHNzLWNhLmNybDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMC
# B4AwdwYIKwYBBQUHAQEEazBpMCoGCCsGAQUFBzABhh5odHRwOi8vdHMtb2NzcC53
# cy5zeW1hbnRlYy5jb20wOwYIKwYBBQUHMAKGL2h0dHA6Ly90cy1haWEud3Muc3lt
# YW50ZWMuY29tL3NoYTI1Ni10c3MtY2EuY2VyMCgGA1UdEQQhMB+kHTAbMRkwFwYD
# VQQDExBUaW1lU3RhbXAtMjA0OC02MB0GA1UdDgQWBBSlEwGpn4XMG24WHl87Map5
# NgB7HTAfBgNVHSMEGDAWgBSvY9bKo06FcuCnvEHzKaI4f4B1YjANBgkqhkiG9w0B
# AQsFAAOCAQEARp6v8LiiX6KZSM+oJ0shzbK5pnJwYy/jVSl7OUZO535lBliLvFeK
# kg0I2BC6NiT6Cnv7O9Niv0qUFeaC24pUbf8o/mfPcT/mMwnZolkQ9B5K/mXM3tRr
# 41IpdQBKK6XMy5voqU33tBdZkkHDtz+G5vbAf0Q8RlwXWuOkO9VpJtUhfeGAZ35i
# rLdOLhWa5Zwjr1sR6nGpQfkNeTipoQ3PtLHaPpp6xyLFdM3fRwmGxPyRJbIblumF
# COjd6nRgbmClVnoNyERY3Ob5SBSe5b/eAL13sZgUchQk38cRLB8AP8NLFMZnHMwe
# BqOQX1xUiz7jM1uCD8W3hgJOcZ/pZkU/djGCAlowggJWAgEBMIGLMHcxCzAJBgNV
# BAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMW
# U3ltYW50ZWMgVHJ1c3QgTmV0d29yazEoMCYGA1UEAxMfU3ltYW50ZWMgU0hBMjU2
# IFRpbWVTdGFtcGluZyBDQQIQe9Tlr7rMBz+hASMEIkFNEjALBglghkgBZQMEAgGg
# gaQwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0y
# MTExMTYyMTAzMjRaMC8GCSqGSIb3DQEJBDEiBCACE2LSeLG5p3tXhhuJLaL4kdgR
# cVMITr/Ura4QpyVg5TA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCDEdM52AH0COU4N
# peTefBTGgPniggE8/vZT7123H99h+DALBgkqhkiG9w0BAQEEggEAOq/R37njpCYF
# uLXeYdefAQNIlPj0NpgGbZKzi7iaXWhQr1Py9hBKqgMRWg9jC8oGRpJGbc2ynmRt
# cNiTmeyOVH5F0i0CmdJlehTVeAtjS/pw9MrhdWzKR1nMx/HbFwfr2IK4u0tgOr7f
# blmLJAaxduSMx17euMAiuWzFonk15R9EeCl2nIdVSz6idW4vyy0weSdAjoOdxsrx
# DY7kqDbNBtnA9yrmi7rxMwgftN+djeiAxi/6Nx8wKnK0/nWKRCHEndE/8wB80qb/
# 7igWx2otdULuj49yDFuLnMqXPDFV+34ZRi72Ix4/0D4QBsfp1uO7hDTydfTprL4h
# Np+mRxu0Bw==
# SIG # End signature block
