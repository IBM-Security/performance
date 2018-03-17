#!/bin/ksh 
instance=ldapdb2 
port=389 
binpath=/opt/IBM/ldap/bin 
while [ true ]; do 
	echo | tee -a /tmp/monitor.out 
	echo ’Begin Monitoring.....’ | tee -a /tmp/monitor.out 
	date | tee -a /tmp/monitor.out 
	echo ’Process info via ps auwx command: ’ | tee -a /tmp/monitor.out 
	ps auwx | egrep ’(slapd|$instance|PID)’ | grep -v grep | tee -a /tmp/monitor.out 
 
  echo ’Memory info via vmstat: ’ | tee -a /tmp/monitor.out 
  #<VMSTAT command-"#"> 
  vmstat -t 2 5 | tee -a /tmp/monitor.out 
  
  echo ’Port activity via netstat: ’ | tee -a /tmp/monitor.out 
  netstat -an | grep $port | tee -a /tmp/monitor.out 
  date | tee -a /tmp/monitor.out echo ’cn=monitor output follows....’ | tee -a /tmp/monitor.out
  
  echo ’cn=monitor output follows....’ | tee -a /tmp/monitor.out
  
  $binpath/ldapsearch -p $port -s base -b cn=monitor objectclass=* | tee -a /tmp/monitor.out 2>&1 
  
  date | tee -a /tmp/monitor.out 
  
  echo ’Sample LDAP query follow: ’ | tee -a /tmp/monitor.out 
  
  ## 
  date | tee -a /tmp/monitor.out 
  echo ’Same query but direct to db2: ’ | tee -a /tmp/monitor.out 
  ## 
  date | tee -a /tmp/monitor.out 
  
  sleep 600 #10minutes 
  
  done