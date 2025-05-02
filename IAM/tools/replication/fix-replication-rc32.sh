#!/bin/bash
# Usage:
# replication-fix-rc32.sh <ReplicationAgreement> <Consumer host> <Consumer AdminDN> <Consumer AdminPW> <Consumer LDAP nonSSL/SSL Port> <Consumer .kdb> <.kdb pw>

#Supplier info
ldapVersion=/opt/ibm/ldap/V6.4
supplierHost=localhost
supplierNonSSLPort=4389
supplierSSLPort=4636
supplierSSLKdb=/home/ldapdb2/idsslapd-ldapdb2/etc/SSL/sslstore.kdb
supplierSSLKdbPw=<.kdb_pwd>
supplierAdminDN=cn=root
supplierAdminPW=<admin-pwd>
supplierInstanceName=ldapdb2

#Check for SSL parameters
if [[ -n "$6"  && -n "$7" ]]
then
   supplier_info="-Z -h $supplierHost -p $supplierSSLPort -K $supplierSSLKdb -P $supplierSSLKdbPw -D $supplierAdminDN -w $supplierAdminPW"
   consumer_info="-Z -h $2 -D $3 -w $4 -p $5 -K $6 -P $7"
else
   supplier_info="-h $supplierHost -p $supplierNonSSLPort -D $supplierAdminDN -w $supplierAdminPW"
   consumer_info="-h $2 -D $3 -w $4 -p $5"
fi

#Check for consumer status in replication
#ldapVersion/bin/idsldapsearch  $supplier_info -s sub -b "$1" objectclass=ibm-repl* | grep ^ibm-replicationLastResult > ibm-replicationLastResult.out
#if [[ ]]

for (( ; ; ))
do
   echo "-------------------------------------------------------------"
   $ldapVersion/bin/idsldapsearch $supplier_info -s sub -b "$1" objectclass=ibm-repl* ibm-replicationLastResult ibm-replicationState | egrep -i "ibm-replicationLastResult|ibm-replicationState" > ibm-replicationLastResult.out
   RESULTCODE=$(cat ibm-replicationLastResult.out | grep -i "ibm-replicationLastResult" | awk 'BEGIN { FS = " " } ; {print $3}')
   REPLCHANGEID=$(cat ibm-replicationLastResult.out | grep -i "ibm-replicationLastResult" | awk 'BEGIN { FS = " " } ; {print $2}')
   OPERATION=$(cat ibm-replicationLastResult.out | grep -i "ibm-replicationLastResult" | awk 'BEGIN { FS = " " } ; {print $4}')
   echo "$(cat ibm-replicationLastResult.out)"
   echo "=>Last change ID: $REPLCHANGEID"
   echo "=>Result Code: $RESULTCODE"

   if [[ $RESULTCODE -eq "81" ]]
   then
     echo "LDAP server in consumer $2 appears to be down! please restart ibmslapd."
     echo "You may start the LDAP server remotely with $ldapVersion/bin/ibmdirctl -h $2 -D $3 -w $4 -p <admin_port> start"
   fi

   REPLSTATE=$(cat ibm-replicationLastResult.out | grep -i "ibm-replicationState" | awk 'BEGIN { FS = "=" } ; {print $2}')
   if [[ $REPLSTATE == "on hold" ]]
   then
     echo "Replication is suspended. Resuming replication for $1..."
     $ldapVersion/bin/idsldapexop $supplier_info -op controlrepl -action resume -ra $1
     echo "Replicate any pending changes immediately..."
     $ldapVersion/bin/idsldapexop $supplier_info -op controlrepl -action replnow -ra $1
   fi

   #error65-Start
   if [[ $RESULTCODE -eq "65" ]]
   then
     DN=$(cat ibm-replicationLastResult.out | awk '{ s = ""; for (i = 5; i <= NF; i++) s = s $i " "; print s }')
     echo "=>Error 65 - schema violation found on entry $DN. Searching for conflicting entry..."
     #Check if entry exists before doing export and import
     $ldapVersion/bin/idsldapsearch $supplier_info -s base -b "$DN" objectclass=* dn
     if [ $? -eq 0 ]
     then
       echo "=>Skipping blocking entry with changeid $REPLCHANGEID from supplier - consumer already has a value for single value attribute"
       $ldapVersion/bin/idsldapexop $supplier_info -op controlqueue -skip $REPLCHANGEID -ra $1
       $ldapVersion/bin/idsldapexop $supplier_info -op controlrepl -action replnow -ra $1
       echo $DN >> listof_corrected_missing_entries.ldif
     fi
   fi


   #Error32-start
    if [[ $RESULTCODE -eq "32" ]]
   then
     DN=$(cat ibm-replicationLastResult.out | awk '{ s = ""; for (i = 5; i <= NF; i++) s = s $i " "; print s }')
     echo "=>Error 32 - no such object found on entry $DN. Searching for missing entry..."
     #Check if entry exists before doing export and import
     $ldapVersion/bin/idsldapsearch $supplier_info -s base -b "$DN" objectclass=* dn

     if [ $? -eq 0 ]
     then
       echo ""
       echo "=>Exporting missing entry $DN from supplier $supplierHost:"
       $ldapVersion/sbin/idsdb2ldif -I $supplierInstanceName -s "$DN" -o missing_entry.ldif
       echo ""
       echo "=>Adding missing entry $DN to consumer $2:"
       $ldapVersion/bin/idsldapadd $consumer_info -k -l -i missing_entry.ldif
       echo "=>Skipping blocking entry with changeid $REPLCHANGEID from supplier:"
       $ldapVersion/bin/idsldapexop $supplier_info -op controlqueue -skip $REPLCHANGEID -ra $1
       $ldapVersion/bin/idsldapexop $supplier_info -op controlrepl -action replnow -ra $1
       echo $DN >> listof_corrected_missing_entries.ldif
     else

       if [[ $OPERATION == "modify" ]]
       then
         echo "Operation is $OPERATION, but entry $DN couldn't be found on supplier $supplierHost so skipping blocking entry..."
         $ldapVersion/bin/idsldapexop $supplier_info -op controlqueue -skip $REPLCHANGEID -ra $1
         $ldapVersion/bin/idsldapexop $supplier_info -op controlrepl -action replnow -ra $1
       else
         echo "=>ibm-replicationLastResult contains error $RESULTCODE, but on a $OPERATION operation and the missing entry no longer exists on supplier - nothing to sync or skip."

       fi
     fi
   fi
   echo "-------------------------------------------------------------"
   echo ""
   echo "Press CTRL+C to stop"
   sleep 2
done
