#==========================================================================
# VENTANA PRINCIPAL  1150x720
#==========================================================================
$form                 = New-Object Windows.Forms.Form
$form.Text            = "RNX TOOL PRO - HYBRID"
$form.ClientSize      = New-Object System.Drawing.Size(1150, 720)
$form.BackColor       = [System.Drawing.Color]::FromArgb(15,15,15)
$form.FormBorderStyle = "FixedSingle"
$form.StartPosition   = "CenterScreen"
$form.AutoScaleMode   = "None"

$sepLine            = New-Object Windows.Forms.Panel
$sepLine.Location   = New-Object System.Drawing.Point(0, 659)
$sepLine.Size       = New-Object System.Drawing.Size(1150, 1)
$sepLine.BackColor  = [System.Drawing.Color]::FromArgb(50,50,50)
$form.Controls.Add($sepLine)

$statusBar          = New-Object Windows.Forms.Panel
$statusBar.Location = New-Object System.Drawing.Point(0, 660)
$statusBar.Size     = New-Object System.Drawing.Size(1150, 24)
$statusBar.BackColor= [System.Drawing.Color]::FromArgb(20,20,20)
$form.Controls.Add($statusBar)

$borderBottom          = New-Object Windows.Forms.Panel
$borderBottom.Location = New-Object System.Drawing.Point(0, 684)
$borderBottom.Size     = New-Object System.Drawing.Size(1150, 1)
$borderBottom.BackColor= [System.Drawing.Color]::FromArgb(50,50,50)
$form.Controls.Add($borderBottom)

$Global:lblStatus          = New-Object Windows.Forms.Label
$Global:lblStatus.Text     = "  RNX TOOL PRO v2.3  |  ADB LISTO  |  Esperando dispositivo..."
$Global:lblStatus.Location = New-Object System.Drawing.Point(8, 5)
$Global:lblStatus.Size     = New-Object System.Drawing.Size(900, 18)
$Global:lblStatus.ForeColor= [System.Drawing.Color]::FromArgb(100,100,100)
$Global:lblStatus.Font     = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Regular)
$statusBar.Controls.Add($Global:lblStatus)

$lblVer             = New-Object Windows.Forms.Label
$lblVer.Text        = "v2.3 PRO"
$lblVer.Location    = New-Object System.Drawing.Point(1058, 5)
$lblVer.Size        = New-Object System.Drawing.Size(80, 18)
$lblVer.ForeColor   = [System.Drawing.Color]::FromArgb(70,70,70)
$lblVer.Font        = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)
$statusBar.Controls.Add($lblVer)

#----------------------------------------------------------
# SIDEBAR  260x659
#----------------------------------------------------------
$sidebar           = New-Object Windows.Forms.Panel
$sidebar.Location  = New-Object System.Drawing.Point(0, 0)
$sidebar.Size      = New-Object System.Drawing.Size(260, 659)
$sidebar.BackColor = [System.Drawing.Color]::FromArgb(25,25,25)
$form.Controls.Add($sidebar)

$sideDiv           = New-Object Windows.Forms.Panel
$sideDiv.Location  = New-Object System.Drawing.Point(259, 0)
$sideDiv.Size      = New-Object System.Drawing.Size(1, 659)
$sideDiv.BackColor = [System.Drawing.Color]::FromArgb(50,50,50)
$form.Controls.Add($sideDiv)

function New-SideLabel($txt, $y) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $txt; $l.Location = New-Object System.Drawing.Point(14, $y)
    $l.ForeColor = [System.Drawing.Color]::LightGray
    $l.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
    $l.AutoSize = $true; $sidebar.Controls.Add($l); return $l
}

# ---- LOGO RNX TOOL (PictureBox con imagen embebida en base64) ----
$logoPath = Join-Path $PSScriptRoot "logox_r1_c1.jpg"
$rnxLogoBmp = [System.Drawing.Image]::FromFile($logoPath)
$picLogo = New-Object Windows.Forms.PictureBox
$picLogo.Image    = $rnxLogoBmp
$picLogo.Location = New-Object System.Drawing.Point(3, 4)
$picLogo.Size     = New-Object System.Drawing.Size(255, 140)
$picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$picLogo.BackColor = [System.Drawing.Color]::FromArgb(25,25,25)
$sidebar.Controls.Add($picLogo)

# Panel monitor centrado en el espacio entre el fin del logo (y=144) y el borde inferior sidebar (y=659)
# Bloque completo: 7 labels + linea HR + 3 labels = 10 elementos x 28px = 280px + 22px (HR+gaps) = ~302px
# Espacio disponible: 659-144 = 515px  =>  margen top = (515-302)/2 = 106px  =>  inicio en y = 144+106 = 250
# Ajuste fino visual: inicio en y=210 para equilibrio optico con el logo
$Global:lblADB    = New-SideLabel "ADB         : DESCONECTADO"  210
$Global:lblDisp   = New-SideLabel "DISPOSITIVO : -"             238
$Global:lblModel  = New-SideLabel "MODELO      : -"             266
$Global:lblRoot   = New-SideLabel "ROOT        : -"             294
$Global:lblChip   = New-SideLabel "CHIPSET     : -"             322
$Global:lblCPU    = New-SideLabel "CPU         : -"             350
$Global:lblSerial = New-SideLabel "SERIAL      : -"             378

$sideHR = New-Object Windows.Forms.Panel
$sideHR.Location = New-Object System.Drawing.Point(14, 410)
$sideHR.Size = New-Object System.Drawing.Size(232, 1)
$sideHR.BackColor = [System.Drawing.Color]::FromArgb(50,50,50)
$sidebar.Controls.Add($sideHR)

$Global:lblModo    = New-SideLabel "MODO        : -"  424
$Global:lblFRP     = New-SideLabel "FRP         : -"  452
$Global:lblStorage = New-SideLabel "STORAGE     : -"  480

#----------------------------------------------------------
# TABS
#----------------------------------------------------------
$tabs          = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object System.Drawing.Point(268, 8)
$tabs.Size     = New-Object System.Drawing.Size(874, 643)
$tabs.Font     = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($tabs)

#==========================================================================
# HELPERS UI
#==========================================================================
function New-GBox($parent,$title,$x,$y,$w,$h,$clr) {
    $g = New-Object Windows.Forms.GroupBox
    $g.Text=$title; $g.ForeColor=[System.Drawing.Color]::$clr
    $g.Location=New-Object System.Drawing.Point($x,$y); $g.Size=New-Object System.Drawing.Size($w,$h)
    $g.Font=New-Object System.Drawing.Font("Segoe UI",8,[System.Drawing.FontStyle]::Bold)
    $parent.Controls.Add($g); return $g
}
function New-FlatBtn($parent,$txt,$clr,$x,$y,$w,$h) {
    $b = New-Object Windows.Forms.Button
    $b.Text=$txt; $b.Location=New-Object System.Drawing.Point($x,$y); $b.Size=New-Object System.Drawing.Size($w,$h)
    $b.FlatStyle="Flat"; $b.ForeColor=[System.Drawing.Color]::$clr
    $b.FlatAppearance.BorderColor=[System.Drawing.Color]::$clr
    $b.Font=New-Object System.Drawing.Font("Segoe UI",7.5,[System.Drawing.FontStyle]::Bold)
    $b.BackColor=[System.Drawing.Color]::FromArgb(35,35,35)
    $parent.Controls.Add($b); return $b
}
function Place-Grid($grp,$labels,$clr,$cols,$bw,$bh,$px,$py,$gx,$gy) {
    $result=@(); $col=0; $row=0
    foreach ($txt in $labels) {
        $bx=$px+$col*($bw+$gx); $by=$py+$row*($bh+$gy)
        $b=New-FlatBtn $grp $txt $clr $bx $by $bw $bh; $result+=$b
        $col++; if ($col -ge $cols) { $col=0; $row++ }
    }
    return $result
}