$VirtIO_OS = ""
$VirtIO_Arch = ""

if ([System.Environment]::Is64BitOperatingSystem) { 
    $VirtIO_Arch = "amd64"
} 
else {
    $VirtIO_Arch = "x86"
}

$ProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName

if ($ProductName -like "Windows 10*") {
    $VirtIO_OS = "w10"
}
elseif ($ProductName -like "Windows 8.1*") {
    $VirtIO_OS = "w8.1"
}
elseif ($ProductName -like "Windows 8*") {
    $VirtIO_OS = "w8"
}
elseif ($ProductName -like "Windows 7*") {
    $VirtIO_OS = "w7"
}
elseif ($ProductName -like "Windows XP*") {
    $VirtIO_OS = "xp"
}
elseif ($ProductName -like "*2019*") {
    $VirtIO_OS = "2k19"
}
elseif ($ProductName -like "*2016*") {
    $VirtIO_OS = "2k16"
}
elseif ($ProductName -like "*2012 R2*") {
    $VirtIO_OS = "2k12R2"
}
elseif ($ProductName -like "*2008 R2*") {
    $VirtIO_OS = "2k8R2"
}
elseif ($ProductName -like "*2012*") {
    $VirtIO_OS = "2k12"
}
elseif ($ProductName -like "*2008*") {
    $VirtIO_OS = "2k8"
}
elseif ($ProductName -like "*2003*") {
    $VirtIO_OS = "2k3"
}
else {
    Write-Host ( "Unknown OS: $ProductName, using 2k19" )
    $VirtIO_OS = "2k19"
}

$DriverPath = Get-Item "E:\*\$VirtIO_OS\$VirtIO_Arch" 

$CertStore = Get-Item "cert:\LocalMachine\TrustedPublisher" 
$CertStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

Get-ChildItem -Recurse -Path $DriverPath -Filter "*.cat" | % {
    $Cert = (Get-AuthenticodeSignature $_.FullName).SignerCertificate

    Write-Host ( "Added {0}, {1} from {2}" -f $Cert.Thumbprint,$Cert.Subject,$_.FullName )

    $CertStore.Add($Cert)
}

$CertStore.Close()

if ([System.Environment]::Is64BitOperatingSystem) { 
    E:\virtio-win-gt-x64.msi /quiet /passive
} 
else {
    E:\virtio-win-gt-x86.msi /quiet /passive
}

E:\virtio-win-guest-tools.exe /quiet /passive
