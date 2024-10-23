# Curl and unzip sysmon off the windows sysinternals page
curl https://download.sysinternals.com/files/Sysmon.zip -OutFile sysmon.zip
Expand-Archive sysmon.zip
# Curl and unzip the swift on config xml
curl https://github.com/SwiftOnSecurity/sysmon-config/archive/refs/heads/master.zip -OutFile sysmon-config.zip
Expand-Archive sysmon-config.zip
# install sysmon 
.\sysmon\sysmon -accepteula -i .\sysmon-config\sysmon-config-master\sysmonconfig-export.xml