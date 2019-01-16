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
# realise it should use Unicode for the UI controls and not ISO-8859-1

# TODO:
# - Add a -NoHide param
# - Add translations
# - Sort Windows 7 downloads

# Parameters
param(
	# (Optional) Name of a pipe the download URL should be sent to.
	# If not provided, a browser window is opened instead.
	[string]$PipeName,
	# (Optional) Name of the perferred locale to use for the UI (e.g. "en-US", "fr-FR")
	# If not provided, the current Windows UI locale is used.
	[string]$Locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name,
	# (Optional) Path to the file that should be used for the UI icon.
	[string]$Icon,
	# (Optional) The title to display on the application window
	[string]$AppTitle = "Fido - Windows Retail ISO Downloader"
)

$Debug = $False
$Testing = $False
if ($Testing) {
	$Locale = "fr-CA"
}
$ENV:PROCESSOR_ARCHITECTURE
$TestLangs = '{"languages":[
	{ "language":"English", "text":"Anglais", "id":"100" },
	{ "language":"English (International)", "text":"Anglais (International)", "id":"101" },
	{ "language":"French", "text":"Français", "id":"102" },
	{ "language":"French (Canadian)", "text":"Français (Canadien)", "id":"103" }
]}'

Write-Host Please Wait...

# Custom Assembly Types
$code = @"
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern IntPtr LoadLibrary(string lpLibFileName);
[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern int LoadString(IntPtr hInstance, uint wID, StringBuilder lpBuffer, int nBufferMax);
[DllImport("Shell32.dll", CharSet = CharSet.Auto, SetLastError = true, BestFitMapping = false, ThrowOnUnmappableChar = true)]
	internal static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
[DllImport("user32.dll")]
	public static extern bool ShowWindow(int handle, int state);

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
$null = [Gui.Utils]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)

# Data
$WindowsVersions = @(
	@(
		"Windows 10",
		@(
			"1809 R2",
			@("Windows 10 Home/Pro", 1060),
			@("Windows 10 Education", 1056)
		),
		@(
			"1809 R1",
			@("Windows 10 Home/Pro", 1019),
			@("Windows 10 Education", 1021)
		),
		@(
			"1803",
			@("Windows 10 Home/Pro", 651),
			@("Windows 10 Education", 655),
			@("Windows 10 Enterprise Eval", 629)
		)
	),
	@(
		"Windows 8.1",
		@(
			"Full",
			@("Windows 8.1/Windows 8.1 Pro", 52),
			@("Windows 8.1 Single Language", 48)
		),
		@(
			"N",
			@("Windows 8.1/Windows 8.1 Pro N", 55)
		)
	),
	@(
		"Windows 7",
		@(
			"SP1",
			@("Windows 7 Ultimate", 8),
			@("Windows 7 Pro", 4),
			@("Windows 7 Home Premium", 6),
			@("Windows 7 Home Basic", 2)
		)
	)
)

# Translated messages. Empty string means same as English
$Translations = @(
	@(
		"en-US"
		"Version"
		"Release"
		"Edition"
		"Language"
		"Arch"
		"Download"
		"Confirm"
		"Close"
		"Cancel"
		"Error"
	),
	@(
		"fr-FR"
		""
		""
		"Édition"
		"Langue de produit"
		""
		"Télécharger"
		"Confirmer"
		"Fermer"
		"Abandonner"
		"Erreur"
	)
)

# Functions
function Select-Language([int]$ArrayIndex, [string]$LangName)
{
	if (($Locale.StartsWith("ar") -and $LangName -like "*Arabic*") -or `
		($Locale -eq "pt-BR" -and $LangName -like "*Brazil*") -or `
		($Locale.StartsWith("ar") -and $LangName -like "*Bulgar*") -or `
		($Locale -eq "zh-CN" -and $LangName -like "*Chinese*" -and $LangName -like "*simp*") -or `
		($Locale -eq "zh-TW" -and $LangName -like "*Chinese*" -and $LangName -like "*trad*") -or `
		($Locale.StartsWith("hr") -and $LangName -like "*Croat*") -or `
		($Locale.StartsWith("cz") -and $LangName -like "*Czech*") -or `
		($Locale.StartsWith("da") -and $LangName -like "*Danish*") -or `
		($Locale.StartsWith("nl") -and $LangName -like "*Dutch*") -or `
		($Locale -eq "en-US" -and $LangName -eq "English") -or `
		($Locale.StartsWith("en") -and $LangName -like "*English*" -and $LangName -like "*inter*") -or `
		($Locale.StartsWith("et") -and $LangName -like "*Eston*") -or `
		($Locale.StartsWith("fi") -and $LangName -like "*Finn*") -or `
		($Locale -eq "fr-CA"  -and $LangName -like "*French*" -and $LangName -like "*Canad*") -or `
		($Locale.StartsWith("fr") -and $LangName -eq "French") -or `
		($Locale.StartsWith("de") -and $LangName -like "*German*") -or `
		($Locale.StartsWith("el") -and $LangName -like "*Greek*") -or `
		($Locale.StartsWith("he") -and $LangName -like "*Hebrew*") -or `
		($Locale.StartsWith("hu") -and $LangName -like "*Hungar*") -or `
		($Locale.StartsWith("id") -and $LangName -like "*Indones*") -or `
		($Locale.StartsWith("it") -and $LangName -like "*Italia*") -or `
		($Locale.StartsWith("ja") -and $LangName -like "*Japan*") -or `
		($Locale.StartsWith("ko") -and $LangName -like "*Korea*") -or `
		($Locale.StartsWith("lv") -and $LangName -like "*Latvia*") -or `
		($Locale.StartsWith("lt") -and $LangName -like "*Lithuania*") -or `
		($Locale.StartsWith("ms") -and $LangName -like "*Malay*") -or `
		($Locale.StartsWith("nb") -and $LangName -like "*Norw*") -or `
		($Locale.StartsWith("fa") -and $LangName -like "*Persia*") -or `
		($Locale.StartsWith("pl") -and $LangName -like "*Polish*") -or `
		($Locale -eq "pt-PT" -and $LangName -eq "Portuguese") -or `
		($Locale.StartsWith("ro") -and $LangName -like "*Romania*") -or `
		($Locale.StartsWith("ru") -and $LangName -like "*Russia*") -or `
		($Locale.StartsWith("sr") -and $LangName -like "*Serbia*") -or `
		($Locale.StartsWith("sk") -and $LangName -like "*Slovak*") -or `
		($Locale.StartsWith("sl") -and $LangName -like "*Slovenia*") -or `
		($Locale -eq "es-ES" -and $LangName -eq "Spanish") -or `
		($Locale.StartsWith("es") -and $Locale -ne "es-ES" -and $LangName -like "*Spanish*") -or `
		($Locale.StartsWith("sv") -and $LangName -like "*Swed*") -or `
		($Locale.StartsWith("th") -and $LangName -like "*Thai*") -or `
		($Locale.StartsWith("tr") -and $LangName -like "*Turk*") -or `
		($Locale.StartsWith("uk") -and $LangName -like "*Ukrain*") -or `
		($Locale.StartsWith("vi") -and $LangName -like "*Vietnam*")) {
		return $ArrayIndex
	}
	return -1
}

function Add-Title([string]$Name)
{
	$Title = New-Object System.Windows.Controls.TextBlock
	$Title.FontSize = $WindowsVersionTitle.FontSize
	$Title.Height = $WindowsVersionTitle.Height;
	$Title.Width = $WindowsVersionTitle.Width;
	$Title.HorizontalAlignment = "Left"
	$Title.VerticalAlignment = "Top"
	$Margin = $WindowsVersionTitle.Margin
	$Margin.Top += $script:Stage * $script:dh
	$Title.Margin = $Margin
	$Title.Text = $Name
	return $Title
}

function Add-Combo
{
	$Combo = New-Object System.Windows.Controls.ComboBox
	$Combo.FontSize = $WindowsVersion.FontSize
	$Combo.Height = $WindowsVersion.Height;
	$Combo.Width = $WindowsVersion.Width;
	$Combo.HorizontalAlignment = "Left"
	$Combo.VerticalAlignment = "Top"
	$Margin = $WindowsVersion.Margin
	$Margin.Top += $script:Stage * $script:dh
	$Combo.Margin = $Margin
	$Combo.SelectedIndex = 0
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
	if (-not $Translations[0].Contains($Text)) {
		Write-Host "Error: '$Text' is not a translatable string"
		return "(Untranslated)"
	}
	foreach($Translation in $Translations) {
		if ($Translation[0].StartsWith($ShortLocale)) {
			for ($i = 1; $i -lt $Translation.Length; $i++) {
				if ($Translations[0][$i] -eq $Text) {
					if ($Translation[$i]) {
						return $Translation[$i]
					}
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

# XAML Form
[xml]$Form = @"
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Height = "162" Width = "380" ResizeMode = "NoResize">
	<Grid Name = "Grid">
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
		<Button Name = "Confirm" FontSize = "16" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
	</Grid>
</Window>
"@

# Globals
$dh = 58;
$Stage = 0
$MaxStage = 4
$SessionId = ""
$ExitCode = 0

# Locale handling
if (-not $Locale) {
	$Locale = "en-US"
}
$ShortLocale = $Locale
if (-not $Locale.StartsWith("zh") -and -not $Locale.StartsWith("pt")) {
	$ShortLocale = $Locale.Substring(0, 2)
}
if ($Debug) {
	Write-Host Using locale "$Locale"
}

# Form creation
$XMLReader = New-Object System.Xml.XmlNodeReader $Form
$XMLForm = [Windows.Markup.XamlReader]::Load($XMLReader)
$XMLForm.Title = $AppTitle
if ($Icon) {
	$XMLForm.Icon = $Icon
} else {
	$XMLForm.Icon = [Gui.Utils]::ExtractIcon("shell32.dll", -41, $true) | ConvertTo-ImageSource
}
if ($Locale.StartsWith("ar") -or  $Locale.StartsWith("fa") -or $Locale.StartsWith("he")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$XMLGrid = $XMLForm.FindName("Grid")
$Confirm = $XMLForm.FindName("Confirm")
$Confirm.Content = Get-Translation("Confirm")

# Populate in the Windows Version dropdown
$WindowsVersionTitle = $XMLForm.FindName("WindowsVersionTitle")
$WindowsVersionTitle.Text = Get-Translation("Version")
$WindowsVersion = $XMLForm.FindName("WindowsVersion")
$array = @()
$i = 0
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

	switch ($Stage) {

		1 { # Windows Version selection => Check server connection and populate Windows Release
			$XMLForm.Title = "Querying Microsoft download servers..."
			Refresh-Control($XMLForm)
			$WindowsVersion.IsEnabled = $False;
			$Confirm.IsEnabled = $False
			Refresh-Control($Confirm)

			$url = "https://www.microsoft.com/" + $Locale + "/software-download/windows10ISO/"
			Write-Host Querying $url

			if (-not $Testing) {
				try {
					$r = Invoke-WebRequest -SessionVariable "Session" $url
					$script:SessionId = $r.ParsedHtml.IHTMLDocument3_GetElementById("session-id").Value
					if (-not $SessionId) {
						throw "Could not read Session ID"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			}
			$script:WindowsReleaseTitle = Add-Title(Get-Translation("Release"))
			$script:WindowsRelease = Add-Combo

			$i = 0
			$array = @()
			foreach ($Version in $WindowsVersions[$WindowsVersion.SelectedValue.Index]) {
				if ($Version -is [array]) {
					$array += @(New-Object PsObject -Property @{ Release = $Version[0]; Index = $i })
				}
				$i++
			}
			$WindowsRelease.ItemsSource = $array
			$WindowsRelease.DisplayMemberPath = "Release"

			$XMLGrid.AddChild($WindowsReleaseTitle)
			$XMLGrid.AddChild($WindowsRelease)
			$XMLForm.Title = $AppTitle
			$Confirm.IsEnabled = $True
		}

		2 { # Windows Release selection => Populate Product Edition
			$WindowsRelease.IsEnabled = $False
			$ProductEditionTitle = Add-Title(Get-Translation("Edition"))
			$script:ProductEdition = Add-Combo

			$array = @()
			foreach ($Release in  $WindowsVersions[$WindowsVersion.SelectedValue.Index][$WindowsRelease.SelectedValue.Index])
			{
				if ($Release -is [array]) {
					$array += @(New-Object PsObject -Property @{ Edition = $Release[0]; Id = $Release[1] })
				}
			}
			$ProductEdition.ItemsSource = $array
			$ProductEdition.DisplayMemberPath = "Edition"

			$XMLGrid.AddChild($ProductEditionTitle)
			$XMLGrid.AddChild($ProductEdition)
		}

		3 { # Product Edition selection => Request and populate Languages
			$ProductEdition.IsEnabled = $False
			$Confirm.IsEnabled = $False
			$Confirm.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Confirm.UpdateLayout() }, $null, $null)
			$LanguageTitle = Add-Title(Get-Translation("Language"))
			$script:Language = Add-Combo

			# Get the Product Edition
			$url = "https://www.microsoft.com/" + $Locale + "/api/controls/contentinclude/html"
			$url += "?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041"
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download,windows10ISO"
			$url += "&query=&action=GetSkuInformationByProductEdition"
			$url += "&sessionId=" + $SessionId
			$url += "&productEditionId=" + $ProductEdition.SelectedValue.Id
			$url += "&sdVersion=2"
			Write-Host Querying $url

			$array = @()
			$index = 0
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
							$s = Select-Language -ArrayIndex $index -LangName $json.language
							if ($s -ge 0) {
								$Language.SelectedIndex = $s
							}
							$index++
						}
					}
					if ($array.Length -eq 0) {
						throw "Could not parse languages"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			} else {
				foreach ($var in $(ConvertFrom-Json –InputObject $TestLangs).languages) {
					$array += @(New-Object PsObject -Property @{ DisplayLanguage = $var.text; Language = $var.language; Id = $var.id })
					$s = Select-Language -ArrayIndex $index -LangName $var.language
					if ($s -ge 0) {
						$Language.SelectedIndex = $s
					}
					$index++
				}
			}
			$Language.ItemsSource = $array
			$Language.DisplayMemberPath = "DisplayLanguage"
			$XMLGrid.AddChild($LanguageTitle)
			$XMLGrid.AddChild($Language)
			$Confirm.IsEnabled = $True
		}

		4 { # Language selection => Request and populate Arch download links
			$Language.IsEnabled = $False
			$Confirm.IsEnabled = $False
			$Confirm.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Confirm.UpdateLayout() }, $null, $null)
			$ArchTitle = Add-Title("Architecture")
			$script:Arch = Add-Combo

			$url = "https://www.microsoft.com/" + $Locale + "/api/controls/contentinclude/html"
			$url += "?pageId=cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b"
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download,windows10ISO"
			$url += "&query=&action=GetProductDownloadLinksBySku"
			$url += "&sessionId=" + $SessionId
			$url += "&skuId=" + $Language.SelectedValue.Id
			$url += "&language=" + $Language.SelectedValue.Language
			$url += "&sdVersion=2"
			Write-Host Querying $url

			$index = 0
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
								$Arch.SelectedIndex = $index
							}
						} elseif ($Type -like "*arm*") {
							$Type = "Arm"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "ARM") {
								$Arch.SelectedIndex = $index
							}
						} elseif ($Type -like "*x64*") {
							$Type = "x64"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64") {
								$Arch.SelectedIndex = $index
							}
						} elseif ($Type -like "*x86*") {
							$Type = "x86"
							if ($ENV:PROCESSOR_ARCHITECTURE -eq "X86") {
								$Arch.SelectedIndex = $index
							}
						}
						$array += @(New-Object PsObject -Property @{ Type = $Type; Link = $Link })
						$index++
					}
					if ($array.Length -eq 0) {
						Write-Host $r.ParsedHtml.body.innerText
						throw "Could not retreive ISO download links"
					}
				} catch {
					Error($_.Exception.Message)
					return
				}
			} else {
				$array += @(New-Object PsObject -Property @{ Type = "x86"; Link = "https://rufus.ie" })
				$index++
				$array += @(New-Object PsObject -Property @{ Type = "x64"; Link = "https://rufus.ie" })
				if ($ENV:PROCESSOR_ARCHITECTURE -eq "AMD64") {
					$Arch.SelectedIndex = $index
				}
			}
			$Arch.ItemsSource = $array
			$Arch.DisplayMemberPath = "Type"
			$XMLGrid.AddChild($ArchTitle)
			$XMLGrid.AddChild($Arch)
			$Confirm.Content = Get-Translation("Download")
			$Confirm.IsEnabled = $True
		}

		5 { # Arch selection => Return selected download link
			$Arch.IsEnabled = $False
			$Confirm.Content = Get-Translation("Close")
			$script:Stage = -1
			if ($PipeName) {
				Send-Message -PipeName $PipeName -Message $Arch.SelectedValue.Link
			} else {
				Write-Host Download Link: $Arch.SelectedValue.Link
				Start-Process -FilePath $Arch.SelectedValue.Link
			}
		}
	}

	if ($Stage -gt 0) {
		$XMLForm.Height += $dh;
		$Margin = $Confirm.Margin
		$Margin.Top += $dh
		$Confirm.Margin = $Margin
	}
})

# We need a job in the background to close the obnoxious Windows "Do you want to accept this cookie" alerts
$ClosePrompt = {
	param($PromptTitle)
	while ($True) {
		Get-Process | Where-Object { $_.MainWindowTitle -match $PromptTitle } | ForEach-Object { $_.CloseMainWindow() }
		Start-Sleep -Milliseconds 200
	}
}
# Get the localized version of the 'Windows Security Warning' title of the cookie prompt
$SecurityWarningTitle = [Gui.Utils]::GetMuiString("urlmon.dll", 2070)
if (-not $SecurityWarningTitle) {
	$SecurityWarningTitle = "Windows Security Warning"
}
$Job = Start-Job -ScriptBlock $ClosePrompt -ArgumentList $SecurityWarningTitle

# Display the dialog
$null = $XMLForm.ShowDialog()

# Clean up & exit
Stop-Job -Job $Job
exit $ExitCode
