#==========================================================================
# 05_tab_adb.ps1  — Logica Tab ADB
# Botones del repo /test, conectividad IDENTICA al repo RNXTool2 original:
#   - Check-ADB  para verificar dispositivo
#   - & adb shell / & adb  directamente (igual que original)
#   - Assert-DeviceReady para operaciones criticas
#==========================================================================

#==========================================================================
# LOGICA - TAB SAMSUNG FLASHER
#==========================================================================
$btnRebRec.Add_Click({
    try {
        Assert-DeviceReady -Mode ADB
        OdinLog "[*] Reiniciando Recovery..."
        Invoke-ADB "reboot recovery" -LogSource "SAMSUNG" | Out-Null
        OdinLog "[OK] Enviado."
    } catch { OdinLog "[!] $_" }
})

$btnRebDown.Add_Click({
    try {
        Assert-DeviceReady -Mode ADB
        OdinLog "[*] Reiniciando Download Mode..."
        Invoke-ADB "reboot download" -LogSource "SAMSUNG" | Out-Null
        OdinLog "[OK] Enviado."
    } catch { OdinLog "[!] $_" }
})

$btnReadOdin.Add_Click({
    $btnReadOdin.Enabled=$false; $btnReadOdin.Text="LEYENDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try { Write-RNXLogSection "LEER INFO ODIN"; Read-OdinInfoPro }
    catch { OdinLog "[!] Error: $_" }
    finally { $btnReadOdin.Enabled=$true; $btnReadOdin.Text="LEER INFO (ODIN)" }
})

$btnStartFlash.Add_Click({
    $btnStartFlash.Enabled=$false; $btnStartFlash.Text="FLASHEANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        Assert-DeviceReady -Mode DOWNLOAD -MinBattery 50 -NeedUnlockedBL
        Write-RNXLogSection "INICIAR FLASHEO SAMSUNG"
        Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "SAMSUNG" }
        Start-FlashPro
    } catch { OdinLog "[!] $_" }
    finally { $btnStartFlash.Enabled=$true; $btnStartFlash.Text="INICIAR FLASHEO" }
})

#==========================================================================
# HELPERS ADB — & adb directo con filtro de ruido, igual que repo original
#==========================================================================
$script:DAEMON_NOISE = "adb server is out of date|killing|daemon not running|starting it now|daemon started successfully|list of devices attached|^\s*\*"

function script:SafeShell {
    param($cmd)
    $r = & adb shell $cmd 2>$null
    if ($null -eq $r) { return "" }
    if ($r -is [array]) {
        return (($r | Where-Object { $_ -and $_ -notmatch $script:DAEMON_NOISE }) -join " ").Trim()
    }
    return (($r.ToString() -split "[\r\n]+") | Where-Object { $_ -and $_ -notmatch $script:DAEMON_NOISE } | Select-Object -First 1).Trim()
}

function script:SafeAdb {
    param($cmd)
    $parts = $cmd -split " "
    $r = & adb @parts 2>$null
    if ($null -eq $r) { return "" }
    if ($r -is [array]) {
        return (($r | Where-Object { $_ -and $_ -notmatch $script:DAEMON_NOISE }) -join " ").Trim()
    }
    return (($r.ToString() -split "[\r\n]+") | Where-Object { $_ -and $_ -notmatch $script:DAEMON_NOISE } | Select-Object -First 1).Trim()
}

#==========================================================================
# LEER INFO COMPLETA
#==========================================================================
$btnReadAdb.Add_Click({
    if ($Global:logAdb) { $Global:logAdb.Clear() }
    AdbLog "[*] Iniciando lectura profunda..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB conectado."; return }
    try {
        $brand     = (script:SafeShell "getprop ro.product.brand").ToUpper()
        $model     = script:SafeShell "getprop ro.product.model"
        $deviceId  = (script:SafeShell "getprop ro.product.device").ToUpper()
        $modDevId  = (script:SafeShell "getprop ro.product.mod_device").ToUpper()
        $devId     = if ($modDevId -ne "" -and $modDevId -ne $deviceId) { $modDevId } else { $deviceId }
        $modelFull = if ($devId -ne "" -and $devId -ne $model.ToUpper()) { "$model [$devId]" } else { $model }
        $android   = script:SafeShell "getprop ro.build.version.release"
        $patch     = script:SafeShell "getprop ro.build.version.security_patch"
        $build     = script:SafeShell "getprop ro.build.display.id"
        $serial    = script:SafeAdb "get-serialno"
        $bootldr   = script:SafeShell "getprop ro.boot.bootloader"
        $buildDisplay = if ($bootldr -ne "") { $bootldr } else { $build }
        $cpu       = Get-TechnicalCPU
        $frp1      = script:SafeShell "getprop ro.frp.pst"
        $oemLk     = script:SafeShell "getprop ro.boot.flash.locked"
        $root      = Detect-Root

        $ufsNode3  = script:SafeShell "ls /sys/class/ufs 2>/dev/null"
        $ufsDev3   = script:SafeShell "ls /dev/block/sda 2>/dev/null"
        $ufsHost3  = script:SafeShell "ls /sys/bus/platform/drivers/ufshcd 2>/dev/null"
        $ufsType3  = script:SafeShell "getprop ro.boot.storage_type"
        $mmcBlk3   = script:SafeShell "ls /dev/block/mmcblk0 2>/dev/null"
        $isUFS3    = ($ufsNode3 -ne "" -or $ufsDev3 -ne "" -or $ufsHost3 -ne "" -or ($ufsType3 -imatch "ufs") -or ($mmcBlk3 -eq "" -and $ufsDev3 -ne ""))
        $storage   = if ($isUFS3) { "UFS" } else { "eMMC" }

        $imeiRaw   = script:SafeShell "service call iphonesubinfo 1"
        $imei = "UNKNOWN"
        if ($imeiRaw -match "[0-9]{15}") { $imei = $Matches[0] }
        elseif ($imeiRaw -match "Result: Parcel") {
            $digits = ($imeiRaw -replace "[^0-9]","")
            if ($digits.Length -ge 15) { $imei = $digits.Substring(0,15) }
        }

        $frpStr  = if ($frp1 -and $frp1 -ne "") { "PRESENT" } else { "NOT SET" }
        $oemStr  = if ($oemLk -eq "1") { "LOCKED" } else { "UNLOCKED" }
        $rootStr = if ($root -ne "NO ROOT") { "SI" } else { "NO" }

        if ($brand -match "SAMSUNG") {
            $cscProp = script:SafeShell "getprop ro.csc.country.code"
            if ($cscProp -eq "") { $cscProp = script:SafeShell "getprop ro.product.csc" }
            if ($cscProp -eq "") { $cscProp = script:SafeShell "getprop ro.csc.sales_code" }
            $kg     = script:SafeShell "getprop ro.boot.kg_state"
            $knox   = script:SafeShell "getprop ro.boot.warranty_bit"
            $binary = Get-BinaryFromBuild $bootldr

            AdbLog ""
            AdbLog "=============================================="
            AdbLog " INFO DISPOSITIVO - $brand $modelFull"
            AdbLog "=============================================="
            AdbLog " MARCA       : $brand"
            AdbLog " MODELO      : $modelFull"
            AdbLog " BUILD       : $buildDisplay"
            AdbLog " ANDROID     : $android"
            AdbLog " BINARIO     : $binary"
            AdbLog " PARCHE SEG. : $patch"
            AdbLog " CPU         : $cpu"
            AdbLog " SERIAL      : $serial"
            AdbLog " STORAGE     : $storage"
            AdbLog " IMEI        : $imei"
            AdbLog ""
            AdbLog " ROOT        : $rootStr"
            AdbLog " FRP         : $frpStr"
            AdbLog " OEM LOCK    : $oemStr"
            AdbLog ""
            if ($cscProp -ne "") { AdbLog " CSC         : $cscProp - $(Get-CSCDecoded $cscProp)" }
            AdbLog " BOOTLOADER  : $bootldr"
            if ($kg   -ne "") { AdbLog " KG STATE    : $kg" }
            if ($knox -ne "") { AdbLog " WARRANTY    : $knox" }
            AdbLog ""
            AdbLog "=============================================="
            AdbLog "[OK] LECTURA COMPLETADA"
        } else {
            AdbLog ""
            AdbLog "=============================================="
            AdbLog " INFO DISPOSITIVO - $brand $modelFull"
            AdbLog "=============================================="
            AdbLog " MARCA       : $brand"
            AdbLog " MODELO      : $modelFull"
            AdbLog " ANDROID     : $android"
            AdbLog " PARCHE SEG. : $patch"
            AdbLog " BUILD       : $build"
            $board_gen = script:SafeShell "getprop ro.board.platform"
            AdbLog " CPU         : $cpu"
            if ($board_gen -ne "") { AdbLog " PLATAFORMA  : $board_gen" }
            AdbLog " SERIAL      : $serial"
            AdbLog " STORAGE     : $storage"
            AdbLog " IMEI        : $imei"
            AdbLog " ROOT        : $rootStr"
            AdbLog " FRP         : $frpStr"
            AdbLog " OEM LOCK    : $oemStr"
            if ($brand -match "XIAOMI|REDMI|POCO") {
                AdbLog ""
                AdbLog " --- XIAOMI ---"
                $miuiVer = script:SafeShell "getprop ro.miui.ui.version.name"
                $region  = script:SafeShell "getprop ro.miui.region"
                $blLk2   = script:SafeShell "getprop ro.boot.flash.locked"
                $vbs     = script:SafeShell "getprop ro.boot.verifiedbootstate"
                $blStr2  = if ($blLk2 -eq "1") { "LOCKED" } else { "UNLOCKED" }
                $antiRaw = script:SafeShell "getprop ro.boot.anti_version"
                AdbLog " MIUI VERSION: $miuiVer"
                AdbLog " REGION      : $region"
                AdbLog " BL LOCK     : $blStr2"
                AdbLog " BOOT STATE  : $vbs"
                if ($antiRaw -ne "" -and $antiRaw -match "^\d+$") { AdbLog " ANTI-ROLLBACK: $antiRaw" }
            }
            AdbLog ""
            AdbLog "=============================================="
            AdbLog "[OK] LECTURA COMPLETADA"
        }

        # Sidebar
        $Global:lblADB.Text       = "ADB         : EN LINEA"
        $Global:lblADB.ForeColor  = [System.Drawing.Color]::Lime
        $Global:lblDisp.Text      = "DISPOSITIVO : $brand"
        $Global:lblModel.Text     = "MODELO      : $modelFull"
        $Global:lblSerial.Text    = "SERIAL      : $serial"
        $Global:lblCPU.Text       = "CPU         : $cpu"
        $Global:lblChip.Text      = "CHIPSET     : $(if ($cpu -match 'MT|MTK|MEDIATEK|Dimensity|Helio') {'MEDIATEK'} elseif ($cpu -match 'EXYNOS') {'EXYNOS'} else {'QUALCOMM'})"
        $Global:lblChip.ForeColor = [System.Drawing.Color]::LightGray
        $Global:lblStorage.Text   = "STORAGE     : $storage"
        $Global:lblFRP.Text       = "FRP         : $frpStr"
        $Global:lblFRP.ForeColor  = if ($frp1 -and $frp1 -ne "") { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::Lime }
        $Global:lblRoot.Text      = "ROOT        : $rootStr"
        $Global:lblRoot.ForeColor = if ($root -ne "NO ROOT") { [System.Drawing.Color]::Lime } else { [System.Drawing.Color]::Red }
        $Global:lblModo.Text      = "MODO        : ADB"
        $Global:lblModo.ForeColor = [System.Drawing.Color]::Cyan
        $Global:lblStatus.Text    = "  RNX TOOL PRO v2.3  |  CONECTADO  |  $modelFull"
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# REINICIO
#==========================================================================
$btnRebootSys.Add_Click({
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo."; return }
    AdbLog "[*] Reiniciando sistema..."; & adb reboot 2>$null; AdbLog "[OK] Equipo reiniciando."
})
$btnRebootRec.Add_Click({
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo."; return }
    AdbLog "[*] Reiniciando a Recovery..."; & adb reboot recovery 2>$null; AdbLog "[OK] Enviado."
})
$btnRebootBl.Add_Click({
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo."; return }
    AdbLog "[*] Reiniciando a Bootloader/Download..."
    & adb reboot bootloader 2>$null; & adb reboot download 2>$null; AdbLog "[OK] Enviado."
})

#==========================================================================
# BLOQUEAR OTA
#==========================================================================
$btnBlkOTA.Add_Click({
    AdbLog "[*] BLOQUEANDO OTA..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    $otaServices = @("com.wssyncmldm","com.sec.android.soagent","com.samsung.android.fmm","com.google.android.gms.update")
    $bloqueados = 0
    foreach ($svc in $otaServices) {
        $r = (& adb shell "pm disable-user --user 0 $svc" 2>$null) -join ""
        if ($r -imatch "disable|success|new state") { AdbLog " [OK] Bloqueado: $svc"; $bloqueados++ }
    }
    & adb shell "settings put global auto_update_status 0" 2>$null | Out-Null
    & adb shell "settings put global software_update_check_point 0" 2>$null | Out-Null
    AdbLog "[+] Servicios bloqueados: $bloqueados / $($otaServices.Count)"
    AdbLog "[OK] OTA bloqueado correctamente."
})

#==========================================================================
# REMOVER ADWARE
#==========================================================================
$btnRemAdware.Add_Click({
    AdbLog "[*] REMOVER ADWARE..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    $pkgs = @("com.facebook.appmanager","com.facebook.services","com.facebook.system",
              "com.netflix.partner.activation","com.amazon.appmanager","com.google.android.videos",
              "com.google.android.music","com.samsung.android.game.gamehome","com.samsung.android.app.tip",
              "com.samsung.android.themestore","com.samsung.android.stickercenter",
              "com.samsung.android.mapsagent","com.dsi.ant.plugins.antplus")
    $removidos = 0
    foreach ($pkg in $pkgs) {
        $res = (& adb shell "pm uninstall --user 0 $pkg" 2>$null) -join ""
        if ($res -imatch "Success") { AdbLog " [OK] Removido: $pkg"; $removidos++ }
    }
    AdbLog "[+] Paquetes removidos: $removidos / $($pkgs.Count)"
    AdbLog "[OK] Proceso completado."
})

#==========================================================================
# FIX LOGO SAMSUNG
#==========================================================================
$btnsA2[2].Add_Click({
    AdbLog "[*] FIX LOGO SAMSUNG..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "FIX LOGO SAMSUNG"
        $rootChk = (& adb shell "su -c id" 2>$null) -join ""
        if ($rootChk -notmatch "uid=0") { AdbLog "[!] ROOT requerido."; return }
        AdbLog "[~] Remontando sistema..."
        & adb shell "su -c 'mount -o remount,rw /'" 2>$null | Out-Null
        & adb shell "su -c 'mount -o remount,rw /system'" 2>$null | Out-Null
        & adb shell "su -c 'rm -f /efs/FactoryApp/factoryapp.apk'" 2>$null | Out-Null
        & adb shell "su -c 'rm -f /system/app/SamsungServiceMode/SamsungServiceMode.apk'" 2>$null | Out-Null
        & adb shell "su -c 'rm -rf /cache/recovery/'" 2>$null | Out-Null
        & adb shell "su -c 'rm -rf /data/system/package_cache/'" 2>$null | Out-Null
        AdbLog "[OK] FIX LOGO completado. Reinicia el equipo."
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# ACTIVAR SIM 2 SAMSUNG
#==========================================================================
$btnsA2[3].Add_Click({
    AdbLog "[*] ACTIVAR SIM 2 SAMSUNG..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "ACTIVAR SIM 2 SAMSUNG"
        & adb shell "settings put global multi_sim_config dsds" 2>$null | Out-Null
        & adb shell "svc data enable" 2>$null | Out-Null
        $r = (& adb shell "getprop persist.radio.multisim.config" 2>$null) -join ""
        AdbLog "[+] Config SIM: $(if($r){$r}else{'(aplicando...)'})"
        & adb shell "am start -n com.android.phone/.MSimMobileNetworkSettings" 2>$null | Out-Null
        AdbLog "[OK] Comando enviado. Reinicia para aplicar."
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# INSTALAR MAGISK APK
#==========================================================================
$btnsA2[4].Add_Click({
    AdbLog "[*] INSTALAR MAGISK APK..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "INSTALAR MAGISK"
        $magiskApk = Join-Path $script:TOOLS_DIR "magisk27.apk"
        if (-not (Test-Path $magiskApk)) { AdbLog "[!] magisk27.apk no encontrado en .\tools\"; return }
        AdbLog "[~] Instalando Magisk APK..."
        $r = (& adb install -r "$magiskApk" 2>$null) -join ""
        if ($r -imatch "Success") { AdbLog "[OK] Magisk instalado. Abre Magisk en el telefono para completar." }
        else { AdbLog "[!] Resultado: $r" }
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# SAMFW FIRMWARE
#==========================================================================
$btnSamFW.Add_Click({
    $btn = $btnSamFW; $btn.Enabled=$false; $btn.Text="DETECTANDO..."
    [System.Windows.Forms.Application]::DoEvents()
    try {
        AdbLog ""; AdbLog "=============================================="
        AdbLog " SAMFW FIRMWARE - RNX TOOL PRO"
        AdbLog "=============================================="
        if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
        AdbLog "[*] Leyendo informacion..."

        $sfModel   = script:SafeShell "getprop ro.product.model"
        $sfBoot    = script:SafeShell "getprop ro.boot.bootloader"
        $sfBuild   = script:SafeShell "getprop ro.build.display.id"
        $sfAndroid = script:SafeShell "getprop ro.build.version.release"
        $sfCsc     = script:SafeShell "getprop ro.csc.sales_code"
        if (-not $sfCsc -or $sfCsc -eq "") { $sfCsc = script:SafeShell "getprop ro.csc.country.code" }
        $sfBrand   = (script:SafeShell "getprop ro.product.brand").ToUpper()

        AdbLog " MARCA   : $sfBrand"
        AdbLog " MODELO  : $(if($sfModel){$sfModel}else{'N/A'})"
        AdbLog " BOOTLDR : $(if($sfBoot){$sfBoot}else{'N/A'})"
        AdbLog " ANDROID : $(if($sfAndroid){$sfAndroid}else{'N/A'})"
        AdbLog " CSC     : $(if($sfCsc){$sfCsc}else{'N/A'})"

        $sfBinary = "0"
        if ($sfBoot -and $sfBoot -ne "") { $sfBinary = Get-BinaryFromBuild $sfBoot }
        elseif ($sfBuild -and $sfBuild -ne "") { $sfBinary = Get-BinaryFromBuild $sfBuild }
        AdbLog " BINARIO : $sfBinary"

        if ($sfBrand -notmatch "SAMSUNG" -and $sfModel -notmatch "^SM-") {
            AdbLog "[!] No es Samsung ($sfBrand)."
            Start-Process "https://samfw.com" -EA SilentlyContinue; return
        }
        if (-not $sfModel -or $sfModel -eq "") {
            AdbLog "[!] Modelo no detectado."
            Start-Process "https://samfw.com" -EA SilentlyContinue; return
        }

        $sfModelClean = $sfModel.Trim().ToUpper() -replace "\s+",""
        $sfUrl = "https://samfw.com/samsung/$sfModelClean"
        if ($sfBinary -ne "0" -and $sfBinary -match "^\d+$") { $sfUrl = "$sfUrl`?binary=$sfBinary" }

        AdbLog "[+] URL  : $sfUrl"
        Start-Process $sfUrl -EA SilentlyContinue
        AdbLog "[OK] Pagina abierta. Region/CSC: $sfCsc"
        AdbLog " -> Descarga AP + BL + CP + CSC"
        AdbLog " -> Usa Tab SAMSUNG FLASHER para flashear"
    } catch { AdbLog "[!] Error: $_" }
    finally { $btn.Enabled=$true; $btn.Text="SAMFW FIRMWARE" }
})

#==========================================================================
# ACTIVAR DIAG XIAOMI
#==========================================================================
$btnDiagXiaomi.Add_Click({
    AdbLog "[*] ACTIVAR DIAG XIAOMI..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "ACTIVAR DIAG XIAOMI"
        & adb shell "am broadcast -a com.miui.networkassistant.action.NETWORK_DIAG" 2>$null | Out-Null
        & adb shell "am broadcast -a android.provider.Telephony.SECRET_CODE -d android_secret_code://4636" 2>$null | Out-Null
        & adb shell "setprop persist.radio.diag_mode 1" 2>$null | Out-Null
        & adb shell "setprop sys.usb.config diag,adb" 2>$null | Out-Null
        $usbConf = (& adb shell "getprop sys.usb.config" 2>$null) -join ""
        AdbLog "[+] USB Config: $(if($usbConf){$usbConf}else{'(aplicando...)'})"
        AdbLog "[OK] Modo diagnostico activado. Si no aparece el puerto DIAG, reinicia."
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# DEBLOAT XIAOMI
#==========================================================================
$btnDebloatXiaomi.Add_Click({
    AdbLog "[*] DEBLOAT XIAOMI..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "DEBLOAT XIAOMI"
        $debloatPkgs = @("com.miui.analytics","com.miui.msa.global","com.xiaomi.gamecenter.sdk.service",
            "com.miui.bugreport","com.miui.cloudservice","com.miui.cloudservice.sysbase",
            "com.miui.cloudbackup","com.miui.fm","com.miui.yellowpage","com.xiaomi.cameraservice",
            "com.miui.cleaner","com.miui.antispam","com.miui.miwallpaper","com.miui.videoplayer",
            "com.miui.mishare.connectivity","com.miui.smarttravel","com.miui.miservice",
            "com.milink.service","com.xiaomi.mipicks","com.miui.systemAdSolution")
        $removidos = 0
        foreach ($pkg in $debloatPkgs) {
            $res = (& adb shell "pm uninstall --user 0 $pkg" 2>$null) -join ""
            if ($res -imatch "Success") { AdbLog " [OK] Removido: $pkg"; $removidos++ }
        }
        AdbLog "[+] Removidos: $removidos / $($debloatPkgs.Count)"
        AdbLog "[OK] Debloat Xiaomi completado."
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# RESET ENTREGA
#==========================================================================
$btnResetEntrega.Add_Click({
    AdbLog "[*] RESET ENTREGA..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    $r = [System.Windows.Forms.MessageBox]::Show(
        "Reset de preparacion para entrega.`n`n- Desactiva opciones de desarrollador`n- Limpia cache`n- Resetea permisos`n`nNO borra datos.`n`nContinuar?",
        "RESET ENTREGA", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
    if ($r -ne "Yes") { AdbLog "[~] Cancelado."; return }
    try {
        Write-RNXLogSection "RESET ENTREGA"
        & adb shell "settings put global development_settings_enabled 0" 2>$null | Out-Null
        & adb shell "settings put global adb_enabled 0" 2>$null | Out-Null
        & adb shell "pm trim-caches 1000000000" 2>$null | Out-Null
        & adb shell "pm reset-permissions" 2>$null | Out-Null
        & adb shell "settings put system screen_off_timeout 60000" 2>$null | Out-Null
        AdbLog "[OK] Reset de entrega completado."
        AdbLog "[~] Equipo listo para entregar."
        AdbLog "[!] ADB fue desactivado."
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# INSTALAR APKs
#==========================================================================
$btnInstalarApks.Add_Click({
    AdbLog "[*] INSTALAR APKs..."
    if (-not (Check-ADB)) { AdbLog "[!] Sin dispositivo ADB."; return }
    try {
        Write-RNXLogSection "INSTALAR APKs"
        $fd = New-Object System.Windows.Forms.OpenFileDialog
        $fd.Title="Selecciona APKs"; $fd.Filter="Android APK (*.apk)|*.apk|Todos|*.*"; $fd.Multiselect=$true
        if ($fd.ShowDialog() -ne "OK") { AdbLog "[~] Cancelado."; return }
        $apks=$fd.FileNames; $ok=0; $fail=0; $total=$apks.Count
        AdbLog "[+] APKs: $total"; AdbLog ""
        foreach ($apk in $apks) {
            $apkName=[System.IO.Path]::GetFileName($apk)
            AdbLog "[~] Instalando: $apkName"
            $r=(& adb install -r "$apk" 2>$null) -join ""
            if ($r -imatch "Success") { AdbLog " [OK] $apkName"; $ok++ }
            else { AdbLog " [!] FALLO: $apkName  $r"; $fail++ }
            [System.Windows.Forms.Application]::DoEvents()
        }
        AdbLog ""; AdbLog "[+] $ok OK / $fail fallo / $total total"
        if ($fail -eq 0) { AdbLog "[OK] Todos instalados." } else { AdbLog "[!] Algunos fallaron." }
    } catch { AdbLog "[!] Error: $_" }
})

#==========================================================================
# AUTOROOT MAGISK 1-CLICK
#==========================================================================
function AutoRoot-Log($msg)        { AdbLog $msg }
function AutoRoot-SetStatus($b,$t) { $b.Text=$t; $b.Enabled=($t -eq "AUTOROOT MAGISK"); [System.Windows.Forms.Application]::DoEvents() }

$script:MAGISK_LEGACY_MODELS = @("SM-A217M","SM-A135M","SM-A515G")
$script:MAGISKBOOT    = Join-Path $script:TOOLS_DIR "magiskboot.exe"
$script:MAGISK_APK_27 = Join-Path $script:TOOLS_DIR "magisk27.apk"
$script:MAGISK_APK_24 = Join-Path $script:TOOLS_DIR "magisk24.apk"
$script:MAGISK_BINS   = Join-Path $script:TOOLS_DIR "magisk_bins"

function Extract-MagiskBins($apkPath,$binsDir,$label) {
    $7z=Join-Path $script:TOOLS_DIR "7z.exe"
    if (-not (Test-Path $7z)) { AutoRoot-Log "[!] 7z.exe no encontrado"; return $false }
    if (-not (Test-Path $binsDir)) { New-Item $binsDir -ItemType Directory -Force | Out-Null }
    AutoRoot-Log "[~] Extrayendo binarios Magisk de $label ..."
    & $7z x "$apkPath" "lib\arm64-v8a\*" "-o$binsDir" -y 2>&1 | Out-Null
    $arm64=Join-Path $binsDir "lib\arm64-v8a"
    if (-not (Test-Path $arm64)) { AutoRoot-Log "[!] lib\arm64-v8a no encontrado"; return $false }
    $map=@{"libmagisk64.so"="magisk64";"libmagisk32.so"="magisk32";"libmagiskinit.so"="magiskinit";"libstub.so"="stub.apk"}
    foreach ($so in $map.Keys) {
        $src=Join-Path $arm64 $so; $dst=Join-Path $binsDir $map[$so]
        if (Test-Path $src) { Copy-Item $src $dst -Force; AutoRoot-Log " [+] $so" }
    }
    if (Test-Path (Join-Path $binsDir "magiskinit")) { AutoRoot-Log "[+] Binarios OK"; return $true }
    AutoRoot-Log "[!] magiskinit no encontrado"; return $false
}

function Get-MagiskbootExe($model) {
    $mc=$model.Trim().ToUpper(); $isL=$false
    foreach ($leg in $script:MAGISK_LEGACY_MODELS) { if ($mc -eq $leg.ToUpper()) { $isL=$true; break } }
    $apk=if($isL){$script:MAGISK_APK_24}else{$script:MAGISK_APK_27}
    $lbl=if($isL){"magisk24.apk (legacy)"}else{"magisk27.apk"}
    AutoRoot-Log "[*] $(if($isL){"LEGACY: $mc -> Magisk 24.1"}else{"Estandar: $mc -> Magisk 27"})"
    if (-not (Test-Path $script:MAGISKBOOT)) { AutoRoot-Log "[!] magiskboot.exe no encontrado en .\tools\"; return $null }
    $bd=Join-Path $script:MAGISK_BINS (if($isL){"v24"}else{"v27"})
    if (-not (Test-Path (Join-Path $bd "magiskinit"))) {
        if (-not (Test-Path $apk)) { AutoRoot-Log "[!] APK no encontrado: $apk"; return $null }
        if (-not (Extract-MagiskBins $apk $bd $lbl)) { return $null }
    } else { AutoRoot-Log "[+] Binarios en cache: $bd" }
    return @{Exe=(Resolve-Path $script:MAGISKBOOT).Path;BinsDir=$bd;IsLegacy=$isL}
}

function Find-BootInTar($tp) {
    $r=@{Target=$null;InitBoot=$false;Boot=$false;InitBootFile=$null;BootFile=$null}
    try {
        if (-not (Get-Command tar -EA SilentlyContinue)) { AutoRoot-Log "[!] tar.exe no encontrado"; return $r }
        AutoRoot-Log "[~] Escaneando TAR..."
        foreach ($line in (& tar -tf "$tp" 2>&1)) {
            $n="$line".Trim()
            if ($n -imatch "init_boot\.img\.lz4$|init_boot\.lz4$") { $r.InitBoot=$true; $r.InitBootFile=$n }
            if ($n -imatch "^boot\.img\.lz4$|^boot\.lz4$")         { $r.Boot=$true;     $r.BootFile=$n }
        }
        if ($r.InitBoot) { $r.Target=$r.InitBootFile } elseif ($r.Boot) { $r.Target=$r.BootFile }
    } catch { AutoRoot-Log "[!] Error: $_" }
    return $r
}

function Extract-SingleFromTar($tp,$tf,$od) {
    try {
        if (-not (Test-Path $od)) { New-Item $od -ItemType Directory -Force | Out-Null }
        AutoRoot-Log "[~] Extrayendo: $tf"
        & tar -xf "$tp" -C "$od" "$tf" 2>&1 | Out-Null
        $ex=Get-ChildItem $od -Recurse -Filter ($tf -replace ".*/","") -EA SilentlyContinue | Select-Object -First 1
        if ($ex -and (Test-Path $ex.FullName)) { AutoRoot-Log "[+] OK: $($ex.FullName)"; return $ex.FullName }
        AutoRoot-Log "[!] No encontrado tras extraccion"
    } catch { AutoRoot-Log "[!] Error: $_" }
    return $null
}

function Expand-LZ4($lp,$oi) {
    $lz4=$null
    foreach ($c in @((Join-Path $script:TOOLS_DIR "lz4.exe"),".\lz4.exe","lz4")) {
        if ((Get-Command $c -EA SilentlyContinue) -or (Test-Path $c)) { $lz4=$c; break }
    }
    if (-not $lz4) {
        foreach ($z in @((Join-Path $script:TOOLS_DIR "7z.exe"),".\7z.exe","7z")) {
            if ((Get-Command $z -EA SilentlyContinue) -or (Test-Path $z)) {
                AutoRoot-Log "[~] LZ4 con 7z..."
                & $z e "$lp" "-o$(Split-Path $oi)" -y 2>&1 | Out-Null
                $ex=Get-ChildItem (Split-Path $oi) -File | Where-Object {$_.Extension -ne ".lz4"} | Sort-Object LastWriteTime -Desc | Select-Object -First 1
                if ($ex) { Rename-Item $ex.FullName $oi -Force -EA SilentlyContinue; return (Test-Path $oi) }
            }
        }
        AutoRoot-Log "[!] lz4.exe no encontrado en .\tools\"; return $false
    }
    AutoRoot-Log "[~] Descomprimiendo LZ4..."
    & $lz4 -d -f "$lp" "$oi" 2>&1 | Out-Null
    return (Test-Path $oi)
}

function Patch-BootWithMagiskboot($ip,$wd,$mbi) {
    if (-not $mbi -or -not (Test-Path $mbi.Exe)) { AutoRoot-Log "[!] magiskboot no encontrado"; return $null }
    if (-not (Test-Path $wd)) { New-Item $wd -ItemType Directory -Force | Out-Null }
    $in=[System.IO.Path]::GetFileName($ip); $wi=Join-Path $wd $in
    Copy-Item $ip $wi -Force
    foreach ($b in @("magisk64","magisk32","magiskinit","stub.apk")) {
        $s=Join-Path $mbi.BinsDir $b; if (Test-Path $s) { Copy-Item $s (Join-Path $wd $b) -Force }
    }
    $od=Get-Location
    try {
        Set-Location $wd
        AutoRoot-Log "[~] 1/3: unpack..."
        & $mbi.Exe unpack $in 2>&1 | ForEach-Object { $l="$_".Trim(); if($l){AutoRoot-Log " $l"} }
        if (-not (Test-Path "ramdisk.cpio")) { AutoRoot-Log "[!] unpack fallo"; return $null }
        AutoRoot-Log "[~] 2/3: inyectando Magisk..."
        & $mbi.Exe cpio ramdisk.cpio "add 0750 init magiskinit" "mkdir 0750 overlay.d" "mkdir 0750 overlay.d/sbin" "patch" 2>&1 | ForEach-Object { $l="$_".Trim(); if($l){AutoRoot-Log " $l"} }
        AutoRoot-Log "[~] 3/3: repack..."
        & $mbi.Exe repack $in 2>&1 | ForEach-Object { $l="$_".Trim(); if($l){AutoRoot-Log " $l"} }
        $nb=Join-Path $wd "new-boot.img"; $pi=Join-Path $wd "patched_$in"
        if (Test-Path $nb) { Rename-Item $nb $pi -Force -EA SilentlyContinue; return if(Test-Path $pi){$pi}else{$nb} }
        $ao=Join-Path $wd "patched_$in"; if (Test-Path $ao) { return $ao }
        AutoRoot-Log "[!] repack no genero imagen"; return $null
    } catch { AutoRoot-Log "[!] Error: $_"; return $null }
    finally {
        Set-Location $od
        foreach ($t in @("kernel","kernel_dtb","ramdisk.cpio","dtb","extra","recovery_dtbo","vbmeta","magisk64","magisk32","magiskinit","stub.apk","config")) {
            Remove-Item (Join-Path $wd $t) -Force -EA SilentlyContinue
        }
    }
}

function Build-OdinTar($ip,$od,$ibh=$null) {
    $on=[System.IO.Path]::GetFileName($ip)
    $ib=if($null -ne $ibh){[bool]$ibh}else{$on -imatch "init_boot"}
    $te=if($ib){"init_boot.img"}else{"boot.img"}; $tn="autoroot_patched.tar"; $tp=[System.IO.Path]::Combine($od,$tn)
    try {
        if (-not (Test-Path $od)) { New-Item $od -ItemType Directory -Force | Out-Null }
        AutoRoot-Log "[~] Creando TAR ($te)..."
        $ib2=[System.IO.File]::ReadAllBytes($ip); $is=$ib2.Length
        $fs=[System.IO.File]::Open($tp,[System.IO.FileMode]::Create,[System.IO.FileAccess]::Write)
        $h=New-Object byte[] 512
        $nb=[System.Text.Encoding]::ASCII.GetBytes($te); [Array]::Copy($nb,0,$h,0,[Math]::Min($nb.Length,99))
        $mb=[System.Text.Encoding]::ASCII.GetBytes("0000644"); [Array]::Copy($mb,0,$h,100,$mb.Length); $h[107]=0
        $ub=[System.Text.Encoding]::ASCII.GetBytes("0000000"); [Array]::Copy($ub,0,$h,108,$ub.Length); $h[115]=0
        [Array]::Copy($ub,0,$h,116,$ub.Length); $h[123]=0
        $sb=[System.Text.Encoding]::ASCII.GetBytes(([Convert]::ToString($is,8).PadLeft(11,[char]'0')+" ")); [Array]::Copy($sb,0,$h,124,$sb.Length)
        $mt=[long]([System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()); $tb=[System.Text.Encoding]::ASCII.GetBytes(([Convert]::ToString($mt,8).PadLeft(11,[char]'0')+" ")); [Array]::Copy($tb,0,$h,136,$tb.Length)
        for($ci=148;$ci -lt 156;$ci++){$h[$ci]=0x20}; $h[156]=[byte][char]'0'
        $xb=[System.Text.Encoding]::ASCII.GetBytes("ustar "); [Array]::Copy($xb,0,$h,257,$xb.Length); $h[263]=0x20; $h[264]=0x20
        $cs=0; for($ci=0;$ci -lt 512;$ci++){$cs+=$h[$ci]}
        $cb=[System.Text.Encoding]::ASCII.GetBytes(([Convert]::ToString($cs,8).PadLeft(6,[char]'0'))); [Array]::Copy($cb,0,$h,148,$cb.Length); $h[154]=0; $h[155]=0x20
        $fs.Write($h,0,512); $fs.Write($ib2,0,$is)
        $pd=(512-($is%512))%512; if($pd -gt 0){$fs.Write((New-Object byte[] $pd),0,$pd)}
        $fs.Write((New-Object byte[] 1024),0,1024); $fs.Close()
        $sz=[math]::Round((Get-Item $tp).Length/1MB,2); AutoRoot-Log "[+] TAR OK: $sz MB"
        $mh=(Get-FileHash $tp -Algorithm MD5).Hash.ToLower(); $mp=[System.IO.Path]::Combine($od,$tn+".md5")
        Copy-Item $tp $mp -Force
        $hl=[System.Text.Encoding]::ASCII.GetBytes("`n$mh $te`n"); $fm=[System.IO.File]::Open($mp,[System.IO.FileMode]::Append); $fm.Write($hl,0,$hl.Length); $fm.Close()
        AutoRoot-Log "[+] MD5: $mh"
        return @{Tar=$tp;TarMd5=$mp;ImgName=$te}
    } catch { AutoRoot-Log "[!] Error: $_" }
    return $null
}

function Flash-WithHeimdall($ip,$pf) {
    $hm=$null
    foreach ($c in @((Join-Path $script:TOOLS_DIR "heimdall.exe"),".\heimdall.exe","heimdall")) {
        if ((Test-Path $c) -or (Get-Command $c -EA SilentlyContinue)) { $hm=$c; break }
    }
    if (-not $hm) { AutoRoot-Log "[!] heimdall.exe no encontrado"; return $false }
    AutoRoot-Log "[~] Flash Heimdall: --$pf"
    return ((Invoke-HeimdallLive "flash --$pf `"$ip`" --no-reboot") -eq 0)
}

function Open-OdinWithBoot($tp) {
    $ri=(Get-Date -Format "yyyyMMdd_HHmmss")+"_"+([System.IO.Path]::GetRandomFileName() -replace "\.","")
    $ot=[System.IO.Path]::Combine([System.IO.Path]::GetTempPath(),"rnx_odin_$ri")
    New-Item $ot -ItemType Directory -Force | Out-Null
    $od=$null; $odir=$null
    foreach ($c in @((Join-Path $script:TOOLS_DIR "Odin3.exe"),".\Odin3.exe")) { if (Test-Path $c) { $odir=(Resolve-Path $c).Path; break } }
    if ($odir) {
        try { Get-ChildItem (Split-Path $odir) -File | ForEach-Object { Copy-Item $_.FullName (Join-Path $ot $_.Name) -Force -EA SilentlyContinue }
              $od=Join-Path $ot "Odin3.exe"; if (-not (Test-Path $od)) { $od=$odir; $ot=$null }
        } catch { $od=$odir; $ot=$null }
    } else {
        $oz=Join-Path $script:TOOLS_DIR "Odin3.zip"
        if (Test-Path $oz) {
            try { Add-Type -AssemblyName System.IO.Compression.FileSystem -EA Stop; [System.IO.Compression.ZipFile]::ExtractToDirectory($oz,$ot) } catch {}
            $f=Get-ChildItem $ot -Recurse -Filter "Odin3.exe" -EA SilentlyContinue | Select-Object -First 1
            if ($f) { $od=$f.FullName }
        }
    }
    try {
        $op="HKCU:\Software\Odin3"; if(-not(Test-Path $op)){New-Item -Path $op -Force|Out-Null}
        Set-ItemProperty -Path $op -Name "EULA" -Value 1 -Type DWord -Force -EA SilentlyContinue
        Set-ItemProperty -Path $op -Name "AgreeEULA" -Value 1 -Type DWord -Force -EA SilentlyContinue
    } catch {}
    if ($od -and (Test-Path (Split-Path $od))) {
        try { [System.IO.File]::WriteAllText((Join-Path (Split-Path $od) "Odin3.ini"),"[Setting]`r`nAgreeEULA=1`r`nEULA=1`r`n",[System.Text.Encoding]::ASCII) } catch {}
    }
    $ck=$false; try { [System.Windows.Forms.Clipboard]::SetText($tp); $ck=$true } catch { try { $tp | & clip.exe; $ck=$true } catch {} }
    if (-not $od) {
        AutoRoot-Log "[!] Odin3 no encontrado. Abre manualmente, carga en AP:"
        AutoRoot-Log "    $tp$(if($ck){' <- portapapeles'})"
        if ($ot -and (Test-Path $ot)) { Remove-Item $ot -Recurse -Force -EA SilentlyContinue }
        Start-Process explorer.exe (Split-Path $tp) -EA SilentlyContinue; return
    }
    $owd=$od|Split-Path; $op=$null
    try { $ps=New-Object System.Diagnostics.ProcessStartInfo; $ps.FileName=$od; $ps.WorkingDirectory=$owd; $ps.UseShellExecute=$true
          $op=[System.Diagnostics.Process]::Start($ps); AutoRoot-Log "[+] Odin3 abierto (PID: $($op.Id))"
    } catch { try { $op=Start-Process $od -WorkingDirectory $owd -PassThru -EA Stop } catch { AutoRoot-Log "[!] No se pudo abrir Odin3" } }
    if ($op -and $ot -and (Test-Path $ot)) {
        $cd=$ot; Start-Job -ScriptBlock { param($pi,$d); try{$p=Get-Process -Id $pi -EA SilentlyContinue;if($p){$p.WaitForExit()}}catch{}; Start-Sleep 3; try{Remove-Item $d -Recurse -Force -EA SilentlyContinue}catch{} } -ArgumentList $op.Id,$cd | Out-Null
    }
    AutoRoot-Log ""; AutoRoot-Log "================================================"
    AutoRoot-Log " ODIN: 1)[AP]  2)Ctrl+V  3)DOWNLOAD MODE  4)[Start]"
    AutoRoot-Log "================================================"
    Start-Process explorer.exe (Split-Path $tp) -EA SilentlyContinue
}

$btnRemFRP.Add_Click({
    $btn=$btnRemFRP; $Global:logAdb.Clear()
    AutoRoot-Log "=============================================="
    AutoRoot-Log " AUTOROOT MAGISK 1-CLICK - RNX TOOL PRO"
    AutoRoot-Log "=============================================="
    AutoRoot-Log " BL desbloqueado + magiskboot.exe + apks + lz4.exe en .\tools\"
    AutoRoot-Log ""
    try { Assert-DeviceReady -Mode ADB -MinBattery 50 }
    catch { AutoRoot-Log "[!] $_"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }
    Write-RNXLogSection "AUTOROOT MAGISK"
    Get-DeviceStateSummary | ForEach-Object { Write-RNXLog "INFO" $_ "ADB" }

    AutoRoot-Log "[1] Leyendo info..."; AutoRoot-SetStatus $btn "LEYENDO INFO..."; [System.Windows.Forms.Application]::DoEvents()
    $devModel   = script:SafeShell "getprop ro.product.model"
    $devAndroid = script:SafeShell "getprop ro.build.version.release"
    $devCsc     = script:SafeShell "getprop ro.csc.sales_code"
    if (-not $devCsc -or $devCsc -eq "") { $devCsc = script:SafeShell "getprop ro.csc.country.code" }
    $oemLock    = script:SafeShell "getprop ro.boot.flash.locked"
    $devSerial  = script:SafeAdb "get-serialno"
    AutoRoot-Log " MODELO  : $(if($devModel){$devModel}else{'N/A'})"
    AutoRoot-Log " ANDROID : $(if($devAndroid){$devAndroid}else{'N/A'})"
    AutoRoot-Log " CSC     : $(if($devCsc){$devCsc}else{'N/A'})"
    AutoRoot-Log " SERIAL  : $(if($devSerial){$devSerial}else{'N/A'})"
    AutoRoot-Log " OEM LOCK: $(if($oemLock -eq '1'){'LOCKED - Abrir BL primero!'}else{'UNLOCKED OK'})"
    AutoRoot-Log ""; [System.Windows.Forms.Application]::DoEvents()

    $mbe=Get-MagiskbootExe $devModel
    if (-not $mbe) { AutoRoot-Log "[!] No se pudo preparar magiskboot"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }
    if ($oemLock -eq "1") { AutoRoot-Log "[!] BOOTLOADER BLOQUEADO."; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }

    AutoRoot-Log "[2] Selecciona AP_*.tar.md5..."; AutoRoot-SetStatus $btn "SELECCIONAR AP..."; [System.Windows.Forms.Application]::DoEvents()
    $fd=New-Object System.Windows.Forms.OpenFileDialog; $fd.Title="Selecciona AP del firmware Samsung"
    $fd.Filter="Samsung AP|AP_*.tar.md5;AP_*.tar;AP_*.md5|Todos|*.*"; $fd.InitialDirectory=$script:SCRIPT_ROOT
    if ($fd.ShowDialog() -ne "OK") { AutoRoot-Log "[~] Cancelado."; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }
    $af=$fd.FileName; AutoRoot-Log "[+] AP: $([System.IO.Path]::GetFileName($af)) ($([math]::Round((Get-Item $af).Length/1MB,1)) MB)"

    AutoRoot-Log "[3] Escaneando TAR..."; AutoRoot-SetStatus $btn "ESCANEANDO TAR..."; [System.Windows.Forms.Application]::DoEvents()
    $bs=Find-BootInTar $af
    if (-not $bs.Target) { AutoRoot-Log "[!] boot.img.lz4 no encontrado"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }
    AutoRoot-Log "[+] Imagen: $($bs.Target)"; $ib=$bs.InitBoot

    AutoRoot-Log "[4] Extrayendo..."; AutoRoot-SetStatus $btn "EXTRAYENDO..."; [System.Windows.Forms.Application]::DoEvents()
    $wb=[System.IO.Path]::Combine($script:SCRIPT_ROOT,"autoroot_work",(Get-Date -Format "yyyyMMdd_HHmmss"))
    $ex=Extract-SingleFromTar $af $bs.Target $wb
    if (-not $ex) { AutoRoot-Log "[!] Error extraccion"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }

    AutoRoot-Log "[5] Descomprimiendo LZ4..."; AutoRoot-SetStatus $btn "DESCOMPRIMIENDO..."; [System.Windows.Forms.Application]::DoEvents()
    $di=Join-Path $wb ([System.IO.Path]::GetFileNameWithoutExtension($ex))
    if (-not (Expand-LZ4 $ex $di)) { AutoRoot-Log "[!] Error LZ4"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }

    AutoRoot-Log "[6] Parcheando con Magisk..."; AutoRoot-SetStatus $btn "PARCHEANDO..."; [System.Windows.Forms.Application]::DoEvents()
    $pp=Patch-BootWithMagiskboot $di (Join-Path $wb "patch") $mbe
    if (-not $pp) { AutoRoot-Log "[!] Error parcheo"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }

    AutoRoot-Log "[7] Generando TAR.MD5..."; AutoRoot-SetStatus $btn "GENERANDO TAR..."; [System.Windows.Forms.Application]::DoEvents()
    $tr=Build-OdinTar $pp $wb $ib
    if (-not $tr) { AutoRoot-Log "[!] Error TAR"; AutoRoot-SetStatus $btn "AUTOROOT MAGISK"; return }

    AutoRoot-Log "[8] Flasheando via Heimdall..."; AutoRoot-SetStatus $btn "FLASHEANDO..."; [System.Windows.Forms.Application]::DoEvents()
    $pf=if($ib){"INIT_BOOT"}else{"BOOT"}
    if (Flash-WithHeimdall $pp $pf) {
        AutoRoot-Log "[OK] FLASH COMPLETADO"
        for ($i=30;$i -gt 0;$i-=5) {
            Start-Sleep -Seconds 5; [System.Windows.Forms.Application]::DoEvents()
            if ((& adb devices 2>$null) | Where-Object { $_ -match " device" }) { break }
            AutoRoot-Log "[~] Esperando ADB... ($i s)"
        }
        $rc=(& adb shell "su -c id" 2>$null) -join ""
        if ($rc -match "uid=0") { AutoRoot-Log "[OK] ROOT CONFIRMADO - Magisk activo"; $Global:lblRoot.Text="ROOT        : SI (MAGISK)"; $Global:lblRoot.ForeColor=[System.Drawing.Color]::Lime }
        else { AutoRoot-Log "[~] Root no confirmado - abre Magisk en el telefono." }
    } else {
        AutoRoot-Log "[~] Heimdall no disponible - abriendo Odin..."
        Open-OdinWithBoot $tr.TarMd5
    }
    AutoRoot-SetStatus $btn "AUTOROOT MAGISK"
})