#
# Fido v1.20 - Retail Windows ISO Downloader
# Copyright © 2019-2021 Pete Batard <pete@akeo.ie>
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
	[string]$PipeName
)
#endregion

try {
	[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}
Write-Host Please Wait...

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

if ($host.version -ge "7.0") {
  Add-Type -WarningAction Ignore -IgnoreWarnings -MemberDefinition $code -Namespace Gui -UsingNamespace System.Runtime, System.IO, System.Text, System.Drawing, System.Globalization -ReferencedAssemblies System.Drawing.Common -Name Utils -ErrorAction Stop
} else {
  Add-Type -MemberDefinition $code -Namespace Gui -UsingNamespace System.IO, System.Text, System.Drawing, System.Globalization -ReferencedAssemblies System.Drawing -Name Utils -ErrorAction Stop
}
Add-Type -AssemblyName PresentationFramework
# Hide the powershell window: https://stackoverflow.com/a/27992426/1069307
[Gui.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0) | Out-Null
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
			@("Windows 8.1", 52),
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
	$Control.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Continue.UpdateLayout() }, $null, $null)
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
	$XMLForm.Title = $(Get-Translation("Error")) + ": " + $ErrorMessage
	Refresh-Control($XMLForm)
	$XMLGrid.Children[2 * $script:Stage + 1].IsEnabled = $True
	$UserInput = [System.Windows.MessageBox]::Show($XMLForm.Title,  $(Get-Translation("Error")), "OK", "Error")
	$script:ExitCode = $script:Stage--
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
$dh = 58;
$Stage = 0
$ltrm = "‎"
$MaxStage = 4
$SessionId = [guid]::NewGuid()
$ExitCode = 100
$Locale = "en-US"
$RequestData = @{}
$RequestData["GetLangs"] = @("a8f8f489-4c7f-463a-9ca6-5cff94d8d041", "getskuinformationbyproductedition" )
$RequestData["GetLinks"] = @("cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b", "GetProductDownloadLinksBySku" )
# Create a semi-random Linux User-Agent string
$FirefoxVersion = Get-Random -Minimum 50 -Maximum 90
$FirefoxDate = Get-RandomDate
$UserAgent = "Mozilla/5.0 (X11; Linux i586; rv:$FirefoxVersion.0) Gecko/$FirefoxDate Firefox/$FirefoxVersion.0"
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

# Form creation
$XMLForm = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $XAML))
$XAML.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $XMLForm.FindName($_.Name) -Scope Script }
$XMLForm.Title = $AppTitle
if ($Icon) {
	$XMLForm.Icon = $Icon
} else {
	$XMLForm.Icon = [Gui.Utils]::ExtractIcon("shell32.dll", -41, $true) | ConvertTo-ImageSource
}
if ($Locale.StartsWith("ar") -or  $Locale.StartsWith("fa") -or $Locale.StartsWith("he")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$WindowsVersionTitle.Text = Get-Translation("Version")
$Continue.Content = Get-Translation("Continue")
$Back.Content = Get-Translation("Close")

# Populate the Windows versions
$i = 0
$array = @()
foreach($Version in $WindowsVersions) {
	$array += @(New-Object PsObject -Property @{ Version = $Version[0][0]; PageType = $Version[0][1]; Index = $i })
	$i++
}
$WindowsVersion.ItemsSource = $array
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
			# Check if the locale we want is available - Fall back to en-US otherwise
			try {
				$url = "https://www.microsoft.com/" + $QueryLocale + "/software-download/"
				Write-Host Querying $url
				Invoke-WebRequest -UseBasicParsing -MaximumRedirection 0 -UserAgent $UserAgent $url | Out-Null
			} catch {
				$script:QueryLocale = "en-US"
			}

			$i = 0
			$array = @()
			foreach ($Version in $WindowsVersions[$WindowsVersion.SelectedValue.Index]) {
				if (($i -ne 0) -and ($Version -is [array])) {
					$array += @(New-Object PsObject -Property @{ Release = $ltrm + $Version[0].Replace(")", ")" + $ltrm); Index = $i })
				}
				$i++
			}

			$script:WindowsRelease = Add-Entry $Stage "Release" $array
			$Back.Content = Get-Translation($English[8])
			$XMLForm.Title = $AppTitle
		}

		2 { # Windows Release selection => Populate Product Edition
			$array = @()
			foreach ($Release in  $WindowsVersions[$WindowsVersion.SelectedValue.Index][$WindowsRelease.SelectedValue.Index])
			{
				if ($Release -is [array]) {
					if (($Release[1] -lt 0x10000) -or ($Locale.StartsWith("ko") -and ($Release[1] -band $ko)) -or ($Locale.StartsWith("zh") -and ($Release[1] -band $zh))) {
						$array += @(New-Object PsObject -Property @{ Edition = $Release[0]; Id = $($Release[1] -band 0xFFFF) })
					}
				}
			}
			$script:ProductEdition = Add-Entry $Stage "Edition" $array
		}

		3 { # Product Edition selection => Request and populate Languages
			$XMLForm.Title = Get-Translation($English[12])
			Refresh-Control($XMLForm)
			$array = @()
			$i = 0;
			if ($WindowsVersion.SelectedValue.PageType -eq "WIN7") {
				foreach ($Entry in $Windows7Versions[$ProductEdition.SelectedValue.Id]) {
					if ($Entry[0] -ne "") {
						$array += @(New-Object PsObject -Property @{ DisplayLanguage = $Entry[0]; Language = $Entry[1]; Id = $i })
					}
					$i++
				}
			} else {
				$url = "https://www.microsoft.com/" + $QueryLocale + "/api/controls/contentinclude/html"
				$url += "?pageId=" + $RequestData["GetLangs"][0]
				$url += "&host=www.microsoft.com"
				$url += "&segments=software-download," + $WindowsVersion.SelectedValue.PageType
				$url += "&query=&action=" + $RequestData["GetLangs"][1]
				$url += "&sessionId=" + $SessionId
				$url += "&productEditionId=" + [Math]::Abs($ProductEdition.SelectedValue.Id)
				$url += "&sdVersion=2"
				Write-Host Querying $url

				$SelectedIndex = 0
				try {
					$r = Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -SessionVariable "Session" $url
					$pattern = '(?s)<select id="product-languages">(.*)?</select>'
					$html = [regex]::Match($r, $pattern).Groups[1].Value
					# Go through an XML conversion to keep all PowerShells happy...
					$html = $html.Replace("selected value", "value")
					$html = "<options>" + $html + "</options>"
					$xml = [xml]$html
					foreach ($var in $xml.options.option) {
						$json = $var.value | ConvertFrom-Json;
						if ($json) {
							$array += @(New-Object PsObject -Property @{ DisplayLanguage = $var.InnerText; Language = $json.language; Id = $json.id })
							if (Select-Language($json.language)) {
								$SelectedIndex = $i
							}
							$i++
						}
					}
					if ($array.Length -eq 0) {
						Throw-Error -Req $r -Alt "Could not parse languages"
					}
				} catch {
					Error($_.Exception.Message)
					break
				}
			}
			$script:Language = Add-Entry $Stage "Language" $array "DisplayLanguage"
			$Language.SelectedIndex = $SelectedIndex
			$XMLForm.Title = $AppTitle
		}

		4 { # Language selection => Request and populate Arch download links
			$array = @()
			if ($WindowsVersion.SelectedValue.PageType -eq "WIN7") {
				foreach ($Version in $Windows7Versions[$ProductEdition.SelectedValue.Id][$Language.SelectedValue.Id][2]) {
					$array += @(New-Object PsObject -Property @{ Type = $Version[0]; Link = $Version[1] })
				}
			} else {
				$XMLForm.Title = Get-Translation($English[12])
				Refresh-Control($XMLForm)
				$url = "https://www.microsoft.com/" + $QueryLocale + "/api/controls/contentinclude/html"
				$url += "?pageId=" + $RequestData["GetLinks"][0]
				$url += "&host=www.microsoft.com"
				$url += "&segments=software-download," + $WindowsVersion.SelectedValue.PageType
				$url += "&query=&action=" + $RequestData["GetLinks"][1]
				$url += "&sessionId=" + $SessionId
				$url += "&skuId=" + $Language.SelectedValue.Id
				$url += "&language=" + $Language.SelectedValue.Language
				$url += "&sdVersion=2"
				Write-Host Querying $url

				$i = 0
				$SelectedIndex = 0

				try {
					$Is64 = [Environment]::Is64BitOperatingSystem
					$r = Invoke-WebRequest -UseBasicParsing -UserAgent $UserAgent -WebSession $Session $url
					$pattern = '(?s)(<input.*?/>)'
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
								$SelectedIndex = $i
							}
							$array += @(New-Object PsObject -Property @{ Type = $json.DownloadType; Link = $json.Uri })
							$i++
						}
					}
					if ($array.Length -eq 0) {
						Throw-Error -Req $r -Alt "Could not retrieve ISO download links"
					}
				} catch {
					Error($_.Exception.Message)
					break
				}
			}

			$script:Arch = Add-Entry $Stage "Architecture" $array "Type"
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
			$Arch.SelectedIndex = $SelectedIndex
			$Continue.Content = Get-Translation("Download")
			$XMLForm.Title = $AppTitle
		}

		5 { # Arch selection => Return selected download link
			if ($PipeName -and -not $Check.IsChecked) {
				Send-Message -PipeName $PipeName -Message $Arch.SelectedValue.Link
			} else {
				Write-Host Download Link: $Arch.SelectedValue.Link
				Start-Process -FilePath $Arch.SelectedValue.Link
			}
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
# MIIcQgYJKoZIhvcNAQcCoIIcMzCCHC8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBGq2C5xqP9tvN9
# 4PFRzj/VzRRF7efttyTaScJEztjIcqCCCy4wggVGMIIELqADAgECAhAkaSZj72wM
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
# XIDj5hY5S6cxghBqMIIQZgIBATCBkTB9MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFD
# T01PRE8gQ0EgTGltaXRlZDEjMCEGA1UEAxMaQ09NT0RPIFJTQSBDb2RlIFNpZ25p
# bmcgQ0ECECRpJmPvbAwKOyPPoxDDZJswDQYJYIZIAWUDBAIBBQCgfDAQBgorBgEE
# AYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3
# AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgqimOQTk8tVwof8f5
# pvZptCV+HNyosJr2EE/a/9GARhswDQYJKoZIhvcNAQEBBQAEggEAIMwr8aeqBaAD
# foTc7RuwRV56vXiOiWpMG82NQjyUsKcfwFabVsjZMvt3iRAbdjnFk3eAZ+RIqasB
# 6M58zOp/0X19870BhU3nPlXbkmIljLQQrtZLBuhAtOgmJXeypWHv4ZqGyoqZ4YG3
# +2wevR6C+5S/0B47CoMQUQ1v1y1S76IJDRvJ8sW7LtEmkgCIpQI5QQ1x7pRg+jX3
# B8adK/RdrLVtmeYjlc1jSJhK86HaWmXuF9DFyH/ncySXZQ4lERvet6RDCaTOT5K1
# YNdSScdSQr5ujG/lhNAzYzdjMrB6XiISmHi8mtTKjrTCKzMpW7uA1VUrq1P7pn8s
# QP/YyRKYv6GCDiswgg4nBgorBgEEAYI3AwMBMYIOFzCCDhMGCSqGSIb3DQEHAqCC
# DgQwgg4AAgEDMQ0wCwYJYIZIAWUDBAIBMIH+BgsqhkiG9w0BCRABBKCB7gSB6zCB
# 6AIBAQYLYIZIAYb4RQEHFwMwITAJBgUrDgMCGgUABBQek/WA68bHr7eCxmX0T/Vd
# ee/SxgIUb0aeoa2p/9QaO1zxbhQfZ1pWBMkYDzIwMjEwNjEwMTAzODU5WjADAgEe
# oIGGpIGDMIGAMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9y
# YXRpb24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMTAvBgNVBAMT
# KFN5bWFudGVjIFNIQTI1NiBUaW1lU3RhbXBpbmcgU2lnbmVyIC0gRzOgggqLMIIF
# ODCCBCCgAwIBAgIQewWx1EloUUT3yYnSnBmdEjANBgkqhkiG9w0BAQsFADCBvTEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDlZlcmlTaWduLCBJbmMuMR8wHQYDVQQLExZW
# ZXJpU2lnbiBUcnVzdCBOZXR3b3JrMTowOAYDVQQLEzEoYykgMjAwOCBWZXJpU2ln
# biwgSW5jLiAtIEZvciBhdXRob3JpemVkIHVzZSBvbmx5MTgwNgYDVQQDEy9WZXJp
# U2lnbiBVbml2ZXJzYWwgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTAeFw0x
# NjAxMTIwMDAwMDBaFw0zMTAxMTEyMzU5NTlaMHcxCzAJBgNVBAYTAlVTMR0wGwYD
# VQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1
# c3QgTmV0d29yazEoMCYGA1UEAxMfU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFtcGlu
# ZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALtZnVlVT52Mcl0a
# gaLrVfOwAa08cawyjwVrhponADKXak3JZBRLKbvC2Sm5Luxjs+HPPwtWkPhiG37r
# pgfi3n9ebUA41JEG50F8eRzLy60bv9iVkfPw7mz4rZY5Ln/BJ7h4OcWEpe3tr4eO
# zo3HberSmLU6Hx45ncP0mqj0hOHE0XxxxgYptD/kgw0mw3sIPk35CrczSf/KO9T1
# sptL4YiZGvXA6TMU1t/HgNuR7v68kldyd/TNqMz+CfWTN76ViGrF3PSxS9TO6AmR
# X7WEeTWKeKwZMo8jwTJBG1kOqT6xzPnWK++32OTVHW0ROpL2k8mc40juu1MO1DaX
# hnjFoTcCAwEAAaOCAXcwggFzMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAG
# AQH/AgEAMGYGA1UdIARfMF0wWwYLYIZIAYb4RQEHFwMwTDAjBggrBgEFBQcCARYX
# aHR0cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGRoXaHR0cHM6Ly9k
# LnN5bWNiLmNvbS9ycGEwLgYIKwYBBQUHAQEEIjAgMB4GCCsGAQUFBzABhhJodHRw
# Oi8vcy5zeW1jZC5jb20wNgYDVR0fBC8wLTAroCmgJ4YlaHR0cDovL3Muc3ltY2Iu
# Y29tL3VuaXZlcnNhbC1yb290LmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAoBgNV
# HREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMzAdBgNVHQ4EFgQU
# r2PWyqNOhXLgp7xB8ymiOH+AdWIwHwYDVR0jBBgwFoAUtnf6aUhHn1MS1cLqBzJ2
# B9GXBxkwDQYJKoZIhvcNAQELBQADggEBAHXqsC3VNBlcMkX+DuHUT6Z4wW/X6t3c
# T/OhyIGI96ePFeZAKa3mXfSi2VZkhHEwKt0eYRdmIFYGmBmNXXHy+Je8Cf0ckUfJ
# 4uiNA/vMkC/WCmxOM+zWtJPITJBjSDlAIcTd1m6JmDy1mJfoqQa3CcmPU1dBkC/h
# Hk1O3MoQeGxCbvC2xfhhXFL1TvZrjfdKer7zzf0D19n2A6gP41P3CnXsxnUuqmaF
# BJm3+AZX4cYO9uiv2uybGB+queM6AL/OipTLAduexzi7D1Kr0eOUA2AKTaD+J20U
# Mvw/l0Dhv5mJ2+Q5FL3a5NPD6itas5VYVQR9x5rsIwONhSrS/66pYYEwggVLMIIE
# M6ADAgECAhB71OWvuswHP6EBIwQiQU0SMA0GCSqGSIb3DQEBCwUAMHcxCzAJBgNV
# BAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMW
# U3ltYW50ZWMgVHJ1c3QgTmV0d29yazEoMCYGA1UEAxMfU3ltYW50ZWMgU0hBMjU2
# IFRpbWVTdGFtcGluZyBDQTAeFw0xNzEyMjMwMDAwMDBaFw0yOTAzMjIyMzU5NTla
# MIGAMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24x
# HzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5ldHdvcmsxMTAvBgNVBAMTKFN5bWFu
# dGVjIFNIQTI1NiBUaW1lU3RhbXBpbmcgU2lnbmVyIC0gRzMwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCvDoqq+Ny/aXtUF3FHCb2NPIH4dBV3Z5Cc/d5O
# Ap5LdvblNj5l1SQgbTD53R2D6T8nSjNObRaK5I1AjSKqvqcLG9IHtjy1GiQo+Bty
# UT3ICYgmCDr5+kMjdUdwDLNfW48IHXJIV2VNrwI8QPf03TI4kz/lLKbzWSPLgN4T
# TfkQyaoKGGxVYVfR8QIsxLWr8mwj0p8NDxlsrYViaf1OhcGKUjGrW9jJdFLjV2wi
# v1V/b8oGqz9KtyJ2ZezsNvKWlYEmLP27mKoBONOvJUCbCVPwKVeFWF7qhUhBIYfl
# 3rTTJrJ7QFNYeY5SMQZNlANFxM48A+y3API6IsW0b+XvsIqbAgMBAAGjggHHMIIB
# wzAMBgNVHRMBAf8EAjAAMGYGA1UdIARfMF0wWwYLYIZIAYb4RQEHFwMwTDAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9kLnN5bWNiLmNvbS9jcHMwJQYIKwYBBQUHAgIwGRoX
# aHR0cHM6Ly9kLnN5bWNiLmNvbS9ycGEwQAYDVR0fBDkwNzA1oDOgMYYvaHR0cDov
# L3RzLWNybC53cy5zeW1hbnRlYy5jb20vc2hhMjU2LXRzcy1jYS5jcmwwFgYDVR0l
# AQH/BAwwCgYIKwYBBQUHAwgwDgYDVR0PAQH/BAQDAgeAMHcGCCsGAQUFBwEBBGsw
# aTAqBggrBgEFBQcwAYYeaHR0cDovL3RzLW9jc3Aud3Muc3ltYW50ZWMuY29tMDsG
# CCsGAQUFBzAChi9odHRwOi8vdHMtYWlhLndzLnN5bWFudGVjLmNvbS9zaGEyNTYt
# dHNzLWNhLmNlcjAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIw
# NDgtNjAdBgNVHQ4EFgQUpRMBqZ+FzBtuFh5fOzGqeTYAex0wHwYDVR0jBBgwFoAU
# r2PWyqNOhXLgp7xB8ymiOH+AdWIwDQYJKoZIhvcNAQELBQADggEBAEaer/C4ol+i
# mUjPqCdLIc2yuaZycGMv41UpezlGTud+ZQZYi7xXipINCNgQujYk+gp7+zvTYr9K
# lBXmgtuKVG3/KP5nz3E/5jMJ2aJZEPQeSv5lzN7Ua+NSKXUASiulzMub6KlN97QX
# WZJBw7c/hub2wH9EPEZcF1rjpDvVaSbVIX3hgGd+Yqy3Ti4VmuWcI69bEepxqUH5
# DXk4qaENz7Sx2j6aescixXTN30cJhsT8kSWyG5bphQjo3ep0YG5gpVZ6DchEWNzm
# +UgUnuW/3gC9d7GYFHIUJN/HESwfAD/DSxTGZxzMHgajkF9cVIs+4zNbgg/Ft4YC
# TnGf6WZFP3YxggJaMIICVgIBATCBizB3MQswCQYDVQQGEwJVUzEdMBsGA1UEChMU
# U3ltYW50ZWMgQ29ycG9yYXRpb24xHzAdBgNVBAsTFlN5bWFudGVjIFRydXN0IE5l
# dHdvcmsxKDAmBgNVBAMTH1N5bWFudGVjIFNIQTI1NiBUaW1lU3RhbXBpbmcgQ0EC
# EHvU5a+6zAc/oQEjBCJBTRIwCwYJYIZIAWUDBAIBoIGkMBoGCSqGSIb3DQEJAzEN
# BgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjEwNjEwMTAzODU5WjAvBgkq
# hkiG9w0BCQQxIgQgmkzzCEFINNxyi0VgUg+Xe7gn6JtaRlUItfaDirYqplswNwYL
# KoZIhvcNAQkQAi8xKDAmMCQwIgQgxHTOdgB9AjlODaXk3nwUxoD54oIBPP72U+9d
# tx/fYfgwCwYJKoZIhvcNAQEBBIIBACpaTpSIzaaiV6meU/x2sTikIngCFWQsY+Pf
# DwhgEX7h36q5O92NtHjrUgGILvPSjtZ27Mpxbm84HCwPUn+VJcDBh4MbD8GDV+X4
# dKx/77zLUiuWlhub1Jz2wDRd+ac0GV1get6dBCAKVomtGqbg5he0p0WvgSosmhXi
# dVr7i59KIaP/J1e2DBDqJPsVFUpCSaaDLfqBR+0hV4sTczRLDrE8k8cTGNzcNhH8
# WzqLCEw0V40Tc5KZ1xghdxIYH3V7SJOIYTKopuN6G/hMnR+hABU578iPjhAQjbel
# Z0EkBvJk8bwoMBGEf3OnB8S7xJRDsbgYLubnItXJ6z5pLcNJRbc=
# SIG # End signature block
