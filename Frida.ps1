#
# Frida - The Full Retail ISO Download Application
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

# NB: You need a BOM on your .ps1 if you want Powershell to actually
# realise it should use Unicode for the UI controls and not ISO-8859-1

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
	[string]$AppTitle = "Frida - Full Retail ISO Downloader"
	# TODO: Add a -NoHide param
)

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
		"en-US",
		"Windows version",
		"Release",
		"Edition",
		"Language"
		"Arch"
		"Download"
		"Confirm"
		"Cancel"
	),
	@(
		"fr-FR",
		"Version de Windows"
		"",
		"Édition",
		"Langue de produit"
		"Arch"
		"Télécharger"
		"Confirmer"
		"Abandonner"
	)
)

# Functions
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

function Exit-App([int]$ExitCode)
{
	$script:ExitCode = $ExitCode
	Get-Process -Id $pid | Foreach-Object { $_.CloseMainWindow() | Out-Null }
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
$Url = ""
$ExitCode = 0

# Locale handling
if (-not $Locale) {
	$Locale = "en-US"
}
$ShortLocale = $Locale
if (-not $Locale.StartsWith("zh") -and -not $Locale.StartsWith("pt")) {
	$ShortLocale = $Locale.Substring(0, 2)
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
if ($Locale.StartsWith("ar-") -or  $Locale.StartsWith("fa-") -or $Locale.StartsWith("he-")) {
	$XMLForm.FlowDirection = "RightToLeft"
}
$XMLGrid = $XMLForm.FindName("Grid")
$Confirm = $XMLForm.FindName("Confirm")
$Confirm.Content = Get-Translation("Confirm")

# Populate in the Windows Version dropdown
$WindowsVersionTitle = $XMLForm.FindName("WindowsVersionTitle")
$WindowsVersionTitle.Text = Get-Translation("Windows version")
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
	if ($script:Stage++ -gt $MaxStage) {
		return
	}

	switch ($Stage) {

		1 { # Windows Version selection => Check server connection and populate Windows Release
			$WindowsVersion.IsEnabled = $False;
			$Confirm.IsEnabled = $False
			# Force a refresh of the Confirm button so it is actually disabled
			$Confirm.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Confirm.UpdateLayout() }, $null, $null)

			$url = "https://www.microsoft.com/" + $Locale + "/software-download/windows10ISO/"
			Write-Host Querying $url

			try {
				$r = Invoke-WebRequest -SessionVariable "Session" $url
				$script:SessionId = $r.ParsedHtml.IHTMLDocument3_GetElementById("session-id").Value
				if (-not $SessionId) {
					throw "Could not read Session ID"
				}
			} catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				Exit-App($Stage)
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

			try {
				$r = Invoke-WebRequest -WebSession $Session $url
				$array = @()
				foreach ($var in $r.ParsedHtml.IHTMLDocument3_GetElementByID("product-languages")) {
					$json = $var.value | ConvertFrom-Json;
					if ($json) {
						$array += @(New-Object PsObject -Property @{ DisplayLanguage = $var.text; Language = $json.language; Id = $json.id })
					}
				}
				if ($array.Length -eq 0) {
					throw "Could not parse languages"
				}
			} catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				Exit-App($Stage)
			}
			$Language.ItemsSource = $array
			$Language.DisplayMemberPath = "DisplayLanguage"
			# TODO: Select the language that matches $Locale
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

			try {
				$r = Invoke-WebRequest -WebSession $Session $url
				$array = @()
				foreach ($var in $r.ParsedHtml.IHTMLDocument3_GetElementsByTagName("span") | Where-Object { $_.className -eq "product-download-type" }) {
					$Link =  $var.ParentNode | Select -Expand href
					$Type = $var.innerText
					# Maybe Microsoft will provide ARM/ARM64 download links one day...
					if ($Type -like "*arm64*") {
						$Type = "Arm64"
					} elseif ($Type -like "*arm*") {
						$Type = "Arm"
					} elseif ($Type -like "*x64*") {
						$Type = "x64"
					} elseif ($Type -like "*x86*") {
						$Type = "x86"
					}
					$array += @(New-Object PsObject -Property @{ Type = $Type; Link = $Link })
				}
				if ($array.Length -eq 0) {
					Write-Host $r.ParsedHtml.body.innerText
					throw "Could not retreive ISO download links"
				}
			} catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				Exit-App($Stage)
			}
			# TODO: Select Arch that matches current host
			$Arch.ItemsSource = $array
			$Arch.DisplayMemberPath = "Type"
			$XMLGrid.AddChild($ArchTitle)
			$XMLGrid.AddChild($Arch)
			$Confirm.Content = "Download"
			$Confirm.IsEnabled = $True
		}

		5 { # Arch selection => Return selected download link
			$Arch.IsEnabled = $False
			$Confirm.IsEnabled = $False
			$script:Url = $Arch.SelectedValue.Link
		}
	}

	if ($Stage -lt ($MaxStage + 1)) {
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
if ($Url) {
	if ($PipeName) {
		Send-Message -PipeName $PipeName -Message $Url
	} else {
		Write-Host Download Link: $Url
		Start-Process -FilePath $Url
	}
}
exit $ExitCode
