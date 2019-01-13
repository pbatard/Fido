#
# DealBreaker - Windows retail ISO download link generator
# Copyright © 2019 Pete Batard <pete@akeo.ie>
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

# Load Assembly and Library
Add-Type -AssemblyName PresentationFramework

# Input parameters
$Language = "en-US"

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
	$Margin.Top += $script:stage * $script:dh
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
	$Margin.Top += $script:stage * $script:dh
	$Combo.Margin = $Margin
	$Combo.SelectedIndex = 0
	return $Combo
}

# XAML Form
# TODO: Use relative extracted icon 
# TODO: Add FlowDirection = "RightToLeft" to <Window> for RTL mode
[xml]$Form = @"
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title = "Windows ISO Download" Height = "162" Width = "380" ResizeMode = "NoResize" Icon="C:/rufus/res/icons/rufus.ico">
	<Grid Name = "Grid">
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0" Text="Windows Version"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
		<Button Name = "Confirm" FontSize = "16" Content = "Confirm" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
	</Grid>
</Window>
"@

# Globals
$dh = 58;
$Stage = 0
$SessionId = ""

$XMLReader = New-Object System.Xml.XmlNodeReader $Form
$XMLForm = [Windows.Markup.XamlReader]::Load($XMLReader)
$XMLGrid = $XMLForm.FindName("Grid")
$Confirm = $XMLForm.FindName('Confirm')

# Populate in the Windows Version dropdown
$WindowsVersionTitle = $XMLForm.FindName('WindowsVersionTitle')
$WindowsVersion = $XMLForm.FindName('WindowsVersion')
$array = @()
$i = 0
foreach($Version in $WindowsVersions) {
	$array += @(New-Object PsObject -Property @{ Version = $Version[0]; Index = $i })
	$i++
}
$WindowsVersion.ItemsSource = $array
$WindowsVersion.DisplayMemberPath = 'Version'

# Button Action
$Confirm.add_click({
	if ($Stage -gt 4) {
		return
	}
	$script:Stage++

	switch ($Stage) {

		1 { # Windows Version selection => Check server connection and populate Windows Release
			$WindowsVersion.IsEnabled = $False;
			$Confirm.IsEnabled = $False
			# Force a refresh of the Confirm button so it is actually disabled
			$Confirm.Dispatcher.Invoke("Render", [Windows.Input.InputEventHandler] { $Confirm.UpdateLayout() }, $null, $null)

			try {
				$r = Invoke-WebRequest -SessionVariable 'Session' "https://www.microsoft.com/en-us/software-download/windows10ISO/"
				$script:SessionId = $r.ParsedHtml.IHTMLDocument3_GetElementById("session-id").Value
				if (-not $SessionId) {
					throw "Could not read Session ID"
				}
				Write-Host "Session ID: $SessionId"
			}
			catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				# TODO: Don't use exit but set a global and close the dialog gracefully
				exit 1
			}
			$script:WindowsReleaseTitle = Add-Title($WindowsVersion.SelectedValue.Version + " Release")
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
			$ProductEditionTitle = Add-Title("Edition")
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
			$LanguageTitle = Add-Title("Language")
			$script:Language = Add-Combo
			# Get the Product Edition

			$url = "https://www.microsoft.com/en-us/api/controls/contentinclude/html"
			$url += "?pageId=a8f8f489-4c7f-463a-9ca6-5cff94d8d041"
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download,windows10ISO"
			$url += "&query=&action=GetSkuInformationByProductEdition"
			$url += "&sessionId=" + $SessionId
			$url += "&productEditionId=" + $ProductEdition.SelectedValue.Id
			$url += "&sdVersion=2"

			try {
				$r = Invoke-WebRequest -WebSession $Session $url
				$array = @()
				foreach ($var in $r.ParsedHtml.IHTMLDocument3_GetElementByID("product-languages")) {
					$json = $var.value | ConvertFrom-Json;
					if ($json) {
						$array += @(New-Object PsObject -Property @{ Language = $json.language; Id = $json.id })
					}
				}
				if ($array.Length -eq 0) {
					throw "Could not parse languages"
				}
			}
			catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				exit 3
			}
			$Language.ItemsSource = $array
			$Language.DisplayMemberPath = "Language"
			# TODO: Select language that matches current MUI settings
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

			$url = "https://www.microsoft.com/en-us/api/controls/contentinclude/html"
			$url += "?pageId=cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b"
			$url += "&host=www.microsoft.com"
			$url += "&segments=software-download,windows10ISO"
			$url += "&query=&action=GetProductDownloadLinksBySku"
			$url += "&sessionId=" + $SessionId
			$url += "&skuId=" + $Language.SelectedValue.Id
			$url += "&language=" + $Language.SelectedValue.Language
			$url += "&sdVersion=2"

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
					throw "Could not fetch download links"
					Write-Host $r.ParsedHtml.body.innerText
				}
			}
			catch {
				Write-Host $_.Exception.Message
				$UserInput = [System.Windows.MessageBox]::Show("Error: " + $_.Exception.Message, "Error", "OK", "Error")
				exit 4
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
			Write-Host $Arch.SelectedValue.Link
		}
	}

	if ($Stage -lt 5) {
		$XMLForm.Height += $dh;
		$Margin = $Confirm.Margin
		$Margin.Top += $dh
		$Confirm.Margin = $Margin
	}

})

# We need a job in the background to close the obnoxious Windows "Do you want to accept this cookie" alerts
$CloseStuff = {
	while ($True) {
		# TODO: We need to get this string from urlmon.dll.mui
		Get-Process | Where-Object { $_.MainWindowTitle -match "Windows Security Warning" } | ForEach-Object { $_.CloseMainWindow() }
		Start-Sleep -Milliseconds 200
	}
}
$job = Start-Job -ScriptBlock $CloseStuff

# Display the dialog
$null = $XMLForm.ShowDialog()

Stop-Job -Job $job
