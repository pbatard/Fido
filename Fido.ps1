#
# Fido - Full Windows ISO Downloader
# Copyright © 2019 Pete Batard <pete@akeo.ie>
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
	# (Optional) Name of a pipe the download URL should be sent to.
	# If not provided, a browser window is opened instead.
	[string]$PipeName,
	# (Optional) '|' separated UI localization strings.
	[string]$LocData,
	# (Optional) Path to the file that should be used for the UI icon.
	[string]$Icon,
	# (Optional) The title to display on the application window
	[string]$AppTitle = "Fido - Windows Retail ISO Downloader"
)
#endregion

#region Testing
$Debug   = $False
$Testing = $False
$Expert  = $False
#endregion

Write-Host Please Wait...

#region Assembly Types
$code = @"
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern IntPtr LoadLibrary(string lpLibFileName);
[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern int LoadString(IntPtr hInstance, uint wID, StringBuilder lpBuffer, int nBufferMax);
[DllImport("shell32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
[DllImport("user32.dll")]
	public static extern bool ShowWindow(IntPtr handle, int state);

	// Returns a localized MUI string from the specified DLL
	public static string GetMuiString(string dll, uint index)
	{
		int MAX_PATH = 255;
		string muiPath = Environment.SystemDirectory + @"\" + CultureInfo.CurrentUICulture.Name + @"\" + dll + ".mui";
		if (!File.Exists(muiPath))
			muiPath = Environment.SystemDirectory + @"\en-US\" + dll + ".mui";
		IntPtr hMui = LoadLibrary(muiPath);
		if (hMui == null)
				return "";
		StringBuilder szString = new StringBuilder(MAX_PATH);
		LoadString(hMui, (uint)index, szString, MAX_PATH);
		return szString.ToString();
	}

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

Add-Type -MemberDefinition $code -Namespace Gui -UsingNamespace "System.IO", "System.Text", "System.Drawing", "System.Globalization" -ReferencedAssemblies System.Drawing -Name Utils -ErrorAction Stop
Add-Type -AssemblyName PresentationFramework
# Hide the powershell window: https://stackoverflow.com/a/27992426/1069307
[Gui.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0) | Out-Null
#endregion

#region Data
# TODO: Fetch this as JSON data?
$WindowsVersions = @(
	@(
		"Windows 10",
		@(
			"1809 R2 (Build 17763.107 - 2018.10)",
			@("Windows 10 Home/Pro", 1060),
			@("Windows 10 Education", 1056),
			@("Windows 10 Home China ", -1061)
		),
		@(
			"1809 R1 (Build 17763.1 - 2018.09)",
			@("Windows 10 Home/Pro", 1019),
			@("Windows 10 Education", 1021),
			@("Windows 10 Home China ", -1020)
		),
		@(
			"1803 (Build 17134.1 - 2018.04)",
			@("Windows 10 Home/Pro", 651),
			@("Windows 10 Education", 655),
			@("Windows 10 Enterprise Eval", -629)
			@("Windows 10 COEM 1803 Home China", -640),
			@("Windows 10 COEM 1803", -639),
			@("Windows 10 1803 Home China", -638),
			@("Windows 10 1803", 637),
			@("Windows 10 COEM 1803_1 Home China", -654),
			@("Windows 10 COEM 1803_1", -653),
			@("Windows 10 1803_1 Home China", -652)
		),
		@(
			"1709 (Build 16299.15 - 2017.09)",
			@("Windows 10 Education 1709", 488),
			@("Windows 10 COEM 1709 Home China", -487),
			@("Windows 10 COEM 1709", -486),
			@("Windows 10 1709 Home China", -485),
			@("Windows 10 1709", 484)
		),
		@(
			"1703 (Build 15063.0 - 2017.03)",
			@("Windows 10 1703 Education N", 424),
			@("Windows 10 1703 Education", 423),
			@("Windows 10 COEM 1703 Home China", -372),
			@("Windows 10 COEM 1703 Single Language", 371),
			@("Windows 10 COEM 1703 N", 370),
			@("Windows 10 COEM 1703", 369),
			@("Windows 10 1703 Home China (Redstone 2)", -364),
			@("Windows 10 1703 Single Language (Redstone 2)", -363),
			@("Windows 10 1703 N (Redstone 2)", 362),
			@("Windows 10 1703 (Redstone 2)", 361)
		),
		@(
			"1607 (Build 14393.0 - 2017.07)",
			@("Windows 10 China Get Genuine (Redstone 1)", -247),
			@("Windows 10 Single Language (Redstone 1)", 246),
			@("Windows 10 N (Redstone 1)", 245),
			@("Windows 10 (Redstone 1)", 244),
			@("Windows 10 Education N (Redstone 1)", 243),
			@("Windows 10 Education (Redstone 1)", 242)
		),
		@(
			"1511 R3 (Build 10586.164 - 2016.04)",
			@("Windows 10 China Get Genuine (Threshold 2, April 2016 Update)", -185),
			@("Windows 10 Single Language (Threshold 2, April 2016 Update)", 184),
			@("Windows 10 N (Threshold 2, April 2016 Update)", -183),
			@("Windows 10 KN (Threshold 2, April 2016 Update)", -182),
			@("Windows 10 Education N (Threshold 2, April 2016 Update)", 181),
			@("Windows 10 Education KN (Threshold 2, April 2016 Update)", -180),
			@("Windows 10 Education (Threshold 2, April 2016 Update)", 179),
			@("Windows 10 (Threshold 2, April 2016 Update)", 178)
		),
		@(
			"1511 R2 (Build 10586.104 - 2016.02)",
			@("Windows 10 Single Language (Threshold 2, February 2016 Update)", 116),
			@("Windows 10 N (Threshold 2, February 2016 Update)", 115),
			@("Windows 10 KN (Threshold 2, February 2016 Update)", -114),
			@("Windows 10 China Get Genuine (Threshold 2, February 2016 Update)", -113),
			@("Windows 10 Education N (Threshold 2, February 2016 Update)", 112),
			@("Windows 10 Education KN (Threshold 2, February 2016 Update)", -111),
			@("Windows 10 Education (Threshold 2, February 2016 Update)", 110),
			@("Windows 10 (Threshold 2, February 2016 Update)", 109)
		),
		@(
			"1511 R1 (Build 10586.0 - 2015.11)",
			@("Windows 10 Single Language (Threshold 2)", 106),
			@("Windows 10 N (Threshold 2)", 105),
			@("Windows 10 KN (Threshold 2)", -104),
			@("Windows 10 China Get Genuine (Threshold 2)", -103),
			@("Windows 10 Education N (Threshold 2)", 102),
			@("Windows 10 Education KN (Threshold 2)", -101),
			@("Windows 10 Education (Threshold 2)", 100),
			@("Windows 10 (Threshold 2)", 99)
		),
		@(
			"1507 (Build 10240.16384 - 2015.07)",
			@("Windows 10 Single Language (Threshold 1)", 82),
			@("Windows 10 N (Threshold 1)", 81),
			@("Windows 10 KN (Threshold 1)", -80),
			@("Windows 10 (Threshold 1)", 79),
			@("Windows 10 China Get Genuine (Threshold 1)", -78),
			@("Windows 10 Education N (Threshold 1)", 77),
			@("Windows 10 Education KN (Threshold 1)", -76),
			@("Windows 10 Education (Threshold 1)", 75)
		)
	),
	@(
		"Windows 8.1",
		@(
			"Update 3 (build 9600)",
			@("Windows 8.1/Windows 8.1 Pro", 52),
			@("Windows 8.1/Windows 8.1 Pro N", 55)
			@("Windows 8.1 Single Language", 48),
			@("Windows 8.1 Professional LE N", 71),
			@("Windows 8.1 Professional LE KN", -70),
			@("Windows 8.1 Professional LE K", -69),
			@("Windows 8.1 Professional LE", 68),
			@("Windows 8.1 KN", -62),
			@("Windows 8.1 K", -61)
		)
	),
	@(
		"Windows 7",
		@(
			"Windows 7 with SP1 (build 7601)",
			@("Windows 7 Ultimate", 8),
			@("Windows 7 Pro", 4),
			@("Windows 7 Home Premium", 6),
			@("Windows 7 Home Basic", 2),
			@("Windows 7 Professional KN SP1 COEM", -98),
			@("Windows 7 Home Premium KN SP1 COEM", -97),
			@("Windows 7 Ultimate SP1 COEM", -96),
			@("Windows 7 Ultimate N SP1 COEM", -95),
			@("Windows 7 Ultimate KN SP1 COEM", -94),
			@("Windows 7 Ultimate K SP1 COEM", -93),
			@("Windows 7 Starter SP1 COEM", -92),
			@("Windows 7 Professional SP1 COEM", -91),
			@("Windows 7 Professional N SP1 COEM", -90),
			@("Windows 7 Home Premium K SP1 COEM", -89),
			@("Windows 7 Home Premium SP1 COEM GGK", -88),
			@("Windows 7 Home Premium SP1 COEM", -87),
			@("Windows 7 Home Premium N SP1 COEM", -86),
			@("Windows 7 Home Basic SP1 COEM GGK", -85),
			@("Windows 7 Home Basic SP1 COEM", -83),
			@("Windows 7 Starter SP1", 28),
			@("Windows 7 Ultimate K SP1", -26),
			@("Windows 7 Ultimate KN SP1", -24),
			@("Windows 7 Home Premium KN SP1", -22),
			@("Windows 7 Home Premium K SP1", -20),
			@("Windows 7 Professional KN SP1", -18),
			@("Windows 7 Professional K SP1", -16),
			@("Windows 7 Ultimate N SP1", 14),
			@("Windows 7 Professional N SP1", 12),
			@("Windows 7 Home Premium N SP1", 10),
			@("Windows 7 Ultimate SP1", 8),
			@("Windows 7 Home Premium SP1", 6),
			@("Windows 7 Professional SP1", 4),
			@("Windows 7 Home Basic SP1", 2)
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
		($SysLocale.StartsWith("en") -and $LangName -like "*English*" -and $LangName -like "*inter*") -or `
		($SysLocale.StartsWith("et") -and $LangName -like "*Eston*") -or `
		($SysLocale.StartsWith("fi") -and $LangName -like "*Finn*") -or `
		($SysLocale -eq "fr-CA"  -and $LangName -like "*French*" -and $LangName -like "*Canad*") -or `
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
	$Margin = $Confirm.Margin
	$Margin.Top += $dh
	$Confirm.Margin = $Margin
	$Margin = $Back.Margin
	$Margin.Top += $dh
	$Back.Margin = $Margin

	return $Combo
}

function Refresh-Control([object]$Control)
{
	$Control.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Confirm.UpdateLayout() }, $null, $null)
}

function Send-Message([string]$PipeName, [string]$Message)
{
	[System.Text.Encoding]$Encoding = [System.Text.Encoding]::UTF8
	$Pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList ".", $PipeName, ([System.IO.Pipes.PipeDirection]::Out), ([System.IO.Pipes.PipeOptions]::None), ([System.Security.Principal.TokenImpersonationLevel]::Impersonation)
	try {
		Write-Host Connecting to $PipeName
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
	if (-not $English.Contains($Text)) {
		Write-Host "Error: '$Text' is not a translatable string"
		return "(Untranslated)"
	}
	if ($Localized) {
		if ($Localized.Length -ne  $English.Length) {
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

function Error([string]$ErrorMessage)
{
	Write-Host $ErrorMessage
	$XMLForm.Title = $(Get-Translation("Error")) + ": " + $ErrorMessage
	Refresh-Control($XMLForm)
	$Confirm.Content = Get-Translation("Close")
	Refresh-Control($Confirm)
	$UserInput = [System.Windows.MessageBox]::Show($XMLForm.Title,  $(Get-Translation("Error")), "OK", "Error")
	$script:ExitCode = $Stage
	$script:Stage = -1
	$Confirm.IsEnabled = $True
}
#endregion

#region Form
[xml]$XAML = @"
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Height = "162" Width = "384" ResizeMode = "NoResize">
	<Grid Name = "XMLGrid">
		<Button Name = "Confirm" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
		<Button Name = "Back" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "194,78,0,0"/>
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
	</Grid>
</Window>
"@
#endregion

#region Globals
$dh = 58;
$Stage = 0
$MaxStage = 4
$SessionId = ""
$ExitCode = 0
$PageType = "windows10ISO"
$Locale = "en-US"

$RequestData = @{}
$RequestData["GetLangs"] = @("a8f8f489-4c7f-463a-9ca6-5cff94d8d041", "GetSkuInformationByProductEdition" )
$RequestData["GetLinks"] = @("cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b", "GetProductDownloadLinksBySku" )
#endregion

# Localization
$EnglishMessages = "en-US|Version|Release|Edition|Language|Architecture|Download|Confirm|Back|Close|Error|Please wait..."
if ($Testing) {
	$LocData = "fr-FR|||Édition|Langue de produit||Télécharger|Confirmer|Retour|Fermer|Erreur|Veuillez patienter..."
	$TestLangs = '{"languages":[
		{ "language":"English", "text":"Anglais", "id":"100" },
		{ "language":"English (International)", "text":"Anglais (International)", "id":"101" },
		{ "language":"French", "text":"Français", "id":"102" },
		{ "language":"French (Canadian)", "text":"Français (Canadien)", "id":"103" }
	]}'
}
[string[]]$English = $EnglishMessages.Split('|')
[string[]]$Localized = $null
if ($LocData -and (-not $LocData.StartsWith("en-US"))) {
	$Localized = $LocData.Split('|')
	if ($Localized.Length -ne $English.Length) {
		Write-Host "Error: Missing or extra translated messages provided ($($Localized.Length)/$($English.Length))"
		exit 1
	}
	$Locale = $Localized[0]
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
$Confirm.Content = Get-Translation("Confirm")
$Back.Content = Get-Translation("Back")
$Back.IsEnabled = $False

# Populate the Windows versions
$i = 0
$array = @()
foreach($Version in $WindowsVersions) {
	$array += @(New-Object PsObject -Property @{ Version = $Version[0]; Index = $i })
	$i++
}
$WindowsVersion.ItemsSource = $array
$WindowsVersion.DisplayMemberPath = "Version"

# Button Action
$Confirm.add_click({
	if ($script:Stage++ -lt 0) {
		Get-Process -Id $pid | Foreach-Object { $_.CloseMainWindow() | Out-Null }
		return
	}

	$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $False
	$Confirm.IsEnabled = $False
	$Back.IsEnabled = $False
	Refresh-Control($Confirm)
	Refresh-Control($Back)

	switch ($Stage) {

		1 { # Windows Version selection => Get a Session ID and populate Windows Release
			$XMLForm.Title = Get-Translation("Please wait...")
			Refresh-Control($XMLForm)

			$url = "https://www.microsoft.com/" + $Locale + "/software-download/windows10ISO/"
			Write-Host Querying $url

			if (-not $Testing) {
				try {
					$r = Invoke-WebRequest -SessionVariable "Session" $url
					$script:SessionId = $r.ParsedHtml.IHTMLDocument3_GetElementById("session-id").Value
					if (-not $SessionId) {
						$ErrorMessage = $r.ParsedHtml.IHTMLDocument3_GetElementByID("errorModalMessage").innerHtml
						if ($ErrorMessage) {
							Write-Host "$(Get-Translation("Error")): ""$ErrorMessage"""
						}
						throw "Could not read Session ID"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			}

			$i = 0
			$array = @()
			foreach ($Version in $WindowsVersions[$WindowsVersion.SelectedValue.Index]) {
				if ($Version -is [array]) {
					$array += @(New-Object PsObject -Property @{ Release = $Version[0]; Index = $i })
				}
				$i++
			}

			$script:WindowsRelease = Add-Entry $Stage "Release" $array
			$XMLForm.Title = $AppTitle
		}

		2 { # Windows Release selection => Populate Product Edition
			$array = @()
			foreach ($Release in  $WindowsVersions[$WindowsVersion.SelectedValue.Index][$WindowsRelease.SelectedValue.Index])
			{
				if ($Release -is [array]) {
					if ($Expert -or ($Release[1] -ge 0)) {
						$array += @(New-Object PsObject -Property @{ Edition = $Release[0]; Id = $Release[1] })
					}
				}
			}
			$script:ProductEdition = Add-Entry $Stage "Edition" $array
		}

		3 { # Product Edition selection => Request and populate Languages

			# Get the Product Edition
			$url = "https://www.microsoft.com/" + $Locale + "/api/controls/contentinclude/html"
			$url += "?pageId=" + $RequestData["GetLangs"][0]
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download," + $PageType
			$url += "&query=&action=" + $RequestData["GetLangs"][1]
			$url += "&sessionId=" + $SessionId
			$url += "&productEditionId=" + [Math]::Abs($ProductEdition.SelectedValue.Id)
			$url += "&sdVersion=2"
			Write-Host Querying $url

			$array = @()
			$i = 0
			$SelectedIndex = 0
			if (-not $Testing) {
				try {
					$r = Invoke-WebRequest -WebSession $Session $url
					foreach ($var in $r.ParsedHtml.IHTMLDocument3_GetElementByID("product-languages")) {
						if ($Debug) {
							Write-Host  $var.value $var.text
						}
						$json = $var.value | ConvertFrom-Json;
						if ($json) {
							$array += @(New-Object PsObject -Property @{ DisplayLanguage = $var.text; Language = $json.language; Id = $json.id })
							if (Select-Language($json.language)) {
								$SelectedIndex = $i
							}
							$i++
						}
					}
					if ($array.Length -eq 0) {
						$ErrorMessage = $r.ParsedHtml.IHTMLDocument3_GetElementByID("errorModalMessage").innerHtml
						if ($ErrorMessage) {
							Write-Host "$(Get-Translation("Error")): ""$ErrorMessage"""
						}
						throw "Could not parse languages"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			} else {
				foreach ($var in $(ConvertFrom-Json –InputObject $TestLangs).languages) {
					$array += @(New-Object PsObject -Property @{ DisplayLanguage = $var.text; Language = $var.language; Id = $var.id })
					if (Select-Language($var.language)) {
						$SelectedIndex = $i
					}
					$i++
				}
			}
			$script:Language = Add-Entry $Stage "Language" $array "DisplayLanguage"
			$Language.SelectedIndex = $SelectedIndex
		}

		4 { # Language selection => Request and populate Arch download links
			$url = "https://www.microsoft.com/" + $Locale + "/api/controls/contentinclude/html"
			$url += "?pageId=" + $RequestData["GetLinks"][0]
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download," + $PageType
			$url += "&query=&action=" + $RequestData["GetLinks"][1]
			$url += "&sessionId=" + $SessionId
			$url += "&skuId=" + $Language.SelectedValue.Id
			$url += "&language=" + $Language.SelectedValue.Language
			$url += "&sdVersion=2"
			Write-Host Querying $url

			$i = 0
			$SelectedIndex = 0
			$array = @()
			if (-not $Testing) {
				try {
					$r = Invoke-WebRequest -WebSession $Session $url
					foreach ($var in $r.ParsedHtml.IHTMLDocument3_GetElementsByTagName("span") | Where-Object { $_.className -eq "product-download-type" }) {
						$Link =  $var.ParentNode | Select -Expand href
						$Type = $var.innerText
						# Maybe Microsoft will provide public ARM/ARM64 retail ISOs one day...
						if ($Type -like "*arm64*") {
							$Type = "Arm64"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "ARM64") {
								$SelectedIndex = $i
							}
						} elseif ($Type -like "*arm*") {
							$Type = "Arm"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "ARM") {
								$SelectedIndex = $i
							}
						} elseif ($Type -like "*x64*") {
							$Type = "x64"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64") {
								$SelectedIndex = $i
							}
						} elseif ($Type -like "*x86*") {
							$Type = "x86"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "X86") {
								$SelectedIndex = $i
							}
						}
						$array += @(New-Object PsObject -Property @{ Type = $Type; Link = $Link })
						$i++
					}
					if ($array.Length -eq 0) {
						$ErrorMessage = $r.ParsedHtml.IHTMLDocument3_GetElementByID("errorModalMessage").innerHtml
						if ($ErrorMessage) {
							Write-Host "$(Get-Translation("Error")): ""$ErrorMessage"""
						}
						throw "Could not retreive ISO download links"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			} else {
				$array += @(New-Object PsObject -Property @{ Type = "x86"; Link = "https://rufus.ie" })
				$i++
				$array += @(New-Object PsObject -Property @{ Type = "x64"; Link = "https://rufus.ie" })
				if ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64") {
					$SelectedIndex = $i
				}
			}

			$script:Arch = Add-Entry $Stage "Architecture" $array "Type"
			$Arch.SelectedIndex = $SelectedIndex
			$Confirm.Content = Get-Translation("Download")
		}

		5 { # Arch selection => Return selected download link
			$script:Stage = -1
			if ($PipeName) {
				Send-Message -PipeName $PipeName -Message $Arch.SelectedValue.Link
			} else {
				Write-Host Download Link: $Arch.SelectedValue.Link
				Start-Process -FilePath $Arch.SelectedValue.Link
			}
			$Confirm.Content = Get-Translation("Close")
		}
	}
	$Confirm.IsEnabled = $True
	if ($Stage -ge 0) {
		$Back.IsEnabled = $True;
	}
})

$Back.add_click({
	$XMLGrid.Children.RemoveAt(2 * $Stage + 3)
	$XMLGrid.Children.RemoveAt(2 * $Stage + 2)
	$XMLGrid.Children[2 * $Stage + 1].IsEnabled = $True
	$XMLForm.Height -= $dh;
	$Margin = $Confirm.Margin
	$Margin.Top -= $dh
	$Confirm.Margin = $Margin
	$Margin = $Back.Margin
	$Margin.Top -= $dh
	$Back.Margin = $Margin
	$script:Stage = $Stage - 1
	if ($Stage -eq 0) {
		$Back.IsEnabled = $False
	}
	if ($Stage -eq 3) {
		$Confirm.Content = Get-Translation("Confirm")
	}
})

# We need a job in the background to close the obnoxious "Do you want to accept this cookie?" Windows alerts
$ClosePrompt = {
	param($PromptTitle)
	while ($True) {
		Get-Process | Where-Object { $_.MainWindowTitle -match $PromptTitle } | ForEach-Object { $_.CloseMainWindow() }
		Start-Sleep -Milliseconds 100
	}
}
# Get the localized version of the 'Windows Security Warning' title of the cookie prompt
$SecurityWarningTitle = [Gui.Utils]::GetMuiString("urlmon.dll", 2070)
if (-not $SecurityWarningTitle) {
	$SecurityWarningTitle = "Windows Security Warning"
}
$Job = Start-Job -ScriptBlock $ClosePrompt -ArgumentList $SecurityWarningTitle

# Display the dialog
$XMLForm.ShowDialog() | Out-Null

# Clean up & exit
Stop-Job -Job $Job
exit $ExitCode
