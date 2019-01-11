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
	$Margin.Top += $global:stage * $dh
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
	$Margin.Top += $global:stage * $dh
	$Combo.Margin = $Margin
	$Combo.SelectedIndex = 0
	return $Combo
}

# Form
[xml]$Form = @"
<!-- TODO: use relative extracted icon -->
<!-- TODO: Add FlowDirection = "RightToLeft" tp <Window> for RTL mode -->
<Window xmlns = "http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title = "Windows ISO Download" Height = "162" Width = "380" ResizeMode = "NoResize" Icon="C:/rufus/res/icons/rufus.ico">
	<Grid Name = "Grid">
		<TextBlock Name = "WindowsVersionTitle" FontSize = "16" Width="340" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="16,8,0,0" Text="Windows Version"/>
		<ComboBox Name = "WindowsVersion" FontSize = "14" Height = "24" Width = "340" HorizontalAlignment = "Left" VerticalAlignment="Top" Margin = "14,34,0,0" SelectedIndex = "0"/>
		<Button Name = "Confirm" FontSize = "16" Content = "Confirm" Height = "26" Width = "160" HorizontalAlignment = "Left" VerticalAlignment = "Top" Margin = "14,78,0,0"/>
	</Grid>
</Window>
"@

$XMLReader = (New-Object System.Xml.XmlNodeReader $Form)
$XMLForm = [Windows.Markup.XamlReader]::Load($XMLReader)
$XMLGrid = $XMLForm.FindName("Grid")
$Confirm = $XMLForm.FindName('Confirm')

# Fill in the first dropdown
$WindowsVersionTitle = $XMLForm.FindName('WindowsVersionTitle')
$WindowsVersion = $XMLForm.FindName('WindowsVersion')
foreach($Version in $WindowsVersions) {
	$null = $WindowsVersion.Items.Add($Version[0])
}
$VersionIndex = 0
$ReleaseIndex = 0
$Sku = 0
$Stage = 0
$dh = 58;

# Button Action
$Confirm.add_click({
	if ($Stage -gt 4) {
		return
	}
	$script:Stage++

	if ($Stage -lt 5) {
		$XMLForm.Height += $dh;
		$Margin = $Confirm.Margin
		$Margin.Top += $dh
		$Confirm.Margin = $Margin
	}

	switch ($Stage) {
		1 {
			$WindowsReleaseTitle = Add-Title($WindowsVersion.SelectedItem + " Release")
			$script:WindowsRelease = Add-Combo
			for ($i = 0; $i -lt $WindowsVersions.Length; $i++) {
				if ($WindowsVersions[$i][0] -eq $WindowsVersion.SelectedItem) {
					$script:VersionIndex = $i
				}
			}
			for($i = 1; $i -lt $WindowsVersions[$VersionIndex].Length; $i++) {
				$WindowsRelease.Items.Add($WindowsVersions[$VersionIndex][$i][0])
			}
			$WindowsVersion.IsEnabled = $False;
			$XMLGrid.AddChild($WindowsReleaseTitle)
			$XMLGrid.AddChild($WindowsRelease)
		}
		2 {
			$ProductEditionTitle = Add-Title("Edition")
			$script:ProductEdition = Add-Combo
			for ($i = 1; $i -lt $WindowsVersions[$VersionIndex].Length; $i++) {
				if ($WindowsVersions[$VersionIndex][$i][0] -eq $WindowsRelease.SelectedItem) {
					$script:ReleaseIndex = $i
				}
			}
			for($i = 1; $i -lt $WindowsVersions[$VersionIndex][$ReleaseIndex].Length; $i++) {
				# Yeah, none of the examples to associate a value to a ComboBox entry in PS *actually* work
				$ProductEdition.Items.Add($WindowsVersions[$VersionIndex][$ReleaseIndex][$i][0])
			}
			$WindowsRelease.IsEnabled = $False
			$XMLGrid.AddChild($ProductEditionTitle)
			$XMLGrid.AddChild($ProductEdition)
		}
		3 {
			$LanguageTitle = Add-Title("Language")
			$script:Language = Add-Combo
			# At last, we can get the SKU
			for ($i = 1; $i -lt $WindowsVersions[$VersionIndex][$ReleaseIndex].Length; $i++) {
				if ($WindowsVersions[$VersionIndex][$ReleaseIndex][$i][0] -eq $ProductEdition.SelectedItem) {
					$script:Sku = $WindowsVersions[$VersionIndex][$ReleaseIndex][$i][1]
					Write-Host "SKU: $Sku"
				}
			}
			$Language.Items.Add("English")
			$Language.Items.Add("German")
			$Language.Items.Add("French")
			$ProductEdition.IsEnabled = $False
			$XMLGrid.AddChild($LanguageTitle)
			$XMLGrid.AddChild($Language)
		}
		4 {
			$ArchTitle = Add-Title("Architecture")
			$script:Arch = Add-Combo
			$Arch.Items.add("x64")
			$Arch.Items.add("x86")
			$Language.IsEnabled = $False
			$XMLGrid.AddChild($ArchTitle)
			$XMLGrid.AddChild($Arch)
			$Confirm.Content = "Download"
		}
		5 {
			$Arch.IsEnabled = $False
			$Confirm.IsEnabled = $False
		}
	}
})

# Show XMLform
$null = $XMLForm.ShowDialog()
