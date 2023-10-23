# IBM Security Performance

## Verify - Identity and Access Management

### Verify examples

#### Verify Support Utility

This directory contains example code for uploading and listing files for use by Verify Support.

### Table of Contents

* [Usage of the example](#usage-of-the-example)
* [Scenarios/User Stories](#scenariosuser-stories)
* [Building the example](#building-the-example)

### Usage of the example
```text
Usage: verifySupportUtility [auth|status|upload|list|results|help] -tenantURL tenantURL [-uploadFile filename] [-uploadComment comment] [-resultsFile filename]
Usage of verifySupportUtility:
        command is one of [ auth, status, upload, list, results, help ]
        (default is 'help')
  -help
        Display the full help text
  -loglevel integer
        Logging Level (default 0)
        0=report success/failure, status codes, response times  (default)
        1=report include response body
        2=report include request body
        3=report full trace (for debugging)
  -tenantURL tenantURL
        URL used to contact tenant: client:secret@tenant.domain
  -uploadFile filename
        Optional file to upload to Verify
  -uploadComment comment
        Optional comment to include with upload to Verify
  -resultsFile filename
        Optional results file to download from Verify

auth	Authenticate to the tenant using the specified client and secret
status	Query status of the file upload service
upload	Upload the specified uploadFile to Verify
list	List uploaded files
results	List any results or download a results file
help	Display the full help text
```


### Scenarios/User Stories

* Customer wishes to provide a large file to SRE via secure channel.
* SRE directs customer to use the Verify support utility with their tenant.
* Customer creates an API client, or uses an existing one, in their tenant.

#### Check the API client credentials work

```text
$ verifySupportUtility auth -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com
Successfully authenticated to mytenant.verify.ibm.com
```

#### Check the service is responding

```text
$ verifySupportUtility status -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com
Service is responding
Status is good
```

#### Upload file

```text
$ verifySupportUtility upload -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com -uploadFile newUsers.csv -uploadComment "New users for load on Jan 17"
Successfully uploaded newUsers.csv
```

* After file is uploaded, SRE processes the file, for example bulkloading.

#### List uploaded files

* Customer can list files that they've uploaded, to ensure that they were successfully received.

```text
$ verifySupportUtility list -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com 
Upload time                     Filename    	Actual	Requested	Comment
2022-01-16 09:41:18 -0600 CST	test.txt    	28  	28      	Test ldif for bulkload
2022-01-17 20:58:13 -0600 CST	newUsers.csv	6901677	6901677 	New users for load on Jan 17
```

#### List any results files

* Customer can see the results of an uploaded file, for example a bulkload

```text
$ verifySupportUtility results -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com 
Results time                    Filename	    Status	        Comment                     	Id
2022-01-18 11:07:20 -0600 CST	newUserIds.csv	Load complete	New users for load on Jan 17     41f751bc7a26bce1879c1613109fdccd
```

#### View a results file

```text
$ verifySupportUtility results -tenantURL XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX:YYYYYYYY@mytenant.verify.ibm.com -resultsFile 41f751bc7a26bce1879c1613109fdccd
```


### Building the example

The bin directory contains statically linked binaries for [Linux](bin/linux/verifySupportUtility), [Mac](bin/darwin/verifySupportUtility) and 
[Windows](bin/windows/verifySupportUtility.exe) 

These don't require any runtime and should just run on the corresponding OS.

If go is installed you can build all three binaries on Linux using the make.sh script.  
Mac and Windows developers should be able to create a similar script.  
Note that you will need the [go install from golang.org](https://golang.org/doc/install) in order to be sure of creating static 
binaries.  The gccgo package that RedHat provides creates dynamically linked binaries that require a go runtime to be installed 
before they will run.
