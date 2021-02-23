# IBM Security Performance

## Identity and Access Management

### Useful tools

#### Replication analysis tools

This directory contains scripts for analyzing SDS replication.  They are built using the [go_ibm_db](https://github.com/ibmdb/go_ibm_db) and [python-ibmdb package](https://github.com/ibmdb/python-ibmdb) drivers.

Running the python versions will require having the [python-ibmdb package](https://github.com/ibmdb/python-ibmdb) installed in addition to DB2.

Compiling the go versions will require having the [go_ibm_db](https://github.com/ibmdb/go_ibm_db) installed.  
The go binaries in bin/ will run on a Linux system with DB2 installed as they are just linked against libdb2.so

repl_data will report on the number of pending changes and the age of the oldest pending change for each consumer of each replication context, based on reading the producer's database.

ldap_sdiff will compare all the entries in two SDS instance databases and report on any differences between them, whether missing entries or differences in modify timestamps.

Both utilities work by connecting to the underlying database and looking at specific tables, so you will need to run them on a system that has DB2 installed and has the ability to connect to the database instance ports.

