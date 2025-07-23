dnsmasq kill all
clear tap
tap create EXP ip 10.0.1.1/24
shell sleep 5
dnsmasq start 10.0.1.1 10.0.1.2 10.0.1.254

dnsmasq configure id ip 00:11:22:33:44:55 10.0.1.5
dnsmasq configure id ip 66:77:88:99:aa:bb 10.0.1.7
dnsmasq configure id dns upstream server 1.1.1.1
dnsmasq configure id options option:dns-server,10.0.1.1
