<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <SetupUILanguage><UILanguage>en-US</UILanguage></SetupUILanguage>
      <InputLocale>040c:0000040c</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>fr-FR</UserLocale>
    </component>
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <DiskConfiguration>
        <Disk wcm:action="add">
          <DiskID>0</DiskID>
          <WillWipeDisk>true</WillWipeDisk>
          <CreatePartitions>
            <CreatePartition wcm:action="add"><Order>1</Order><Type>EFI</Type><Size>300</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>2</Order><Type>MSR</Type><Size>16</Size></CreatePartition>
            <CreatePartition wcm:action="add"><Order>3</Order><Type>Primary</Type><Extend>true</Extend></CreatePartition>
          </CreatePartitions>
          <ModifyPartitions>
            <ModifyPartition wcm:action="add"><Order>1</Order><PartitionID>1</PartitionID><Format>FAT32</Format><Label>System</Label></ModifyPartition>
            <ModifyPartition wcm:action="add"><Order>2</Order><PartitionID>3</PartitionID><Format>NTFS</Format><Label>Windows</Label><Letter>C</Letter></ModifyPartition>
          </ModifyPartitions>
        </Disk>
      </DiskConfiguration>
      <ImageInstall>
        <OSImage>
          <InstallFrom><MetaData wcm:action="add"><Key>/IMAGE/INDEX</Key><Value>2</Value></MetaData></InstallFrom>
          <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
        </OSImage>
      </ImageInstall>
      <UserData>
        <AcceptEula>true</AcceptEula>
        <FullName>InfraReady</FullName>
        <Organization>InfraReady</Organization>
      </UserData>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <ComputerName>WIN-DC01</ComputerName>
      <TimeZone>Romance Standard Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-TCPIP" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <Interfaces>
        <Interface wcm:action="add">
          <Identifier>BC-24-11-EA-70-74</Identifier>
          <Ipv4Settings><DhcpEnabled>false</DhcpEnabled></Ipv4Settings>
          <UnicastIpAddresses><IpAddress wcm:action="add" wcm:keyValue="1">192.168.50.10/24</IpAddress></UnicastIpAddresses>
          <Routes><Route wcm:action="add"><Identifier>0</Identifier><Prefix>0.0.0.0/0</Prefix><NextHopAddress>192.168.50.1</NextHopAddress></Route></Routes>
        </Interface>
      </Interfaces>
    </component>
    <component name="Microsoft-Windows-DNS-Client" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <Interfaces>
        <Interface wcm:action="add">
          <Identifier>BC-24-11-EA-70-74</Identifier>
          <DNSServerSearchOrder><IpAddress wcm:action="add" wcm:keyValue="1">1.1.1.1</IpAddress></DNSServerSearchOrder>
        </Interface>
      </Interfaces>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <InputLocale>040c:0000040c</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>fr-FR</UserLocale>
    </component>
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserAccounts>
        <AdministratorPassword><Value>__ADMIN_PASSWORD__</Value><PlainText>true</PlainText></AdministratorPassword>
      </UserAccounts>
      <AutoLogon>
        <Enabled>true</Enabled><LogonCount>1</LogonCount><Username>Administrator</Username>
        <Password><Value>__ADMIN_PASSWORD__</Value><PlainText>true</PlainText></Password>
      </AutoLogon>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add"><Order>1</Order>
          <CommandLine>powershell -NoProfile -ExecutionPolicy Bypass -Command "Enable-PSRemoting -SkipNetworkProfileCheck -Force; Set-NetFirewallRule -Name WINRM-HTTP-In-TCP -RemoteAddress 192.168.50.0/24; Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In; Set-NetFirewallRule -Name FPS-ICMP4-ERQ-In -RemoteAddress 192.168.50.0/24"</CommandLine>
          <Description>Enable WinRM and ping from the lab subnet only</Description>
        </SynchronousCommand>
        <SynchronousCommand wcm:action="add"><Order>2</Order>
          <CommandLine>powershell -NoProfile -Command "New-Item -ItemType File -Force C:\Windows\Temp\infraready-firstlogon.done"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
