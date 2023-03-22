# IBM Security Performance

## Verify - Identity and Access Management

### Verify examples

#### CSV Hasher

This directory contains example code for pre-hashing passwords in a CSV file before creating users using the Verify APIs.
This allows you to hash passwords at the point that they are extracted from an existing user registry,

### Table of Contents

* [Usage of the example](#usage-of-the-example)
* [Building the example](#building-the-example)

### Usage of the example
```text
Usage csvHasher -input_file csv_file -output_file csv_file [-column_name column_name | -column_number column_number] [-hash_size 256 | 512]
   csvHasher converts the specified column of a CSV file to SHA256 or SHA512 format usable as an ldap password
   The format generated is consistent with https://docs.ldap.com/specs/draft-stroeder-hashed-userpassword-values-01.txt

```

The csvHasher utility accepts 3 required parameters (either column_name or column_number can be specified) and two optional parameters:
- input_file - A CSV file that contains user records
- output_file - The name of a CSV file to create with the processed user records
- column_name - The name of the column that should be replaced by the ldap-formatted SHA256 value of the data
- column_number - The number (starting at 1) of the column that should be replaced by the ldap-formatted SHA256 value of the data
- hash_size - The size (256 or 512) of the hashes to generate.  Defaults to 256.
- help - Display the full help text

The format generated is consistent with https://docs.ldap.com/specs/draft-stroeder-hashed-userpassword-values-01.txt and is
accepted by the Verify Cloud Directory APIs.  Hashed values can be substituted for clear text passwords when creating or 
modifying users via API.

### Building the example

The bin directory contains statically linked binaries for [Linux](bin/linux/csvHasher), [Mac](bin/darwin/csvHasher) and 
[Windows](bin/windows/csvHasher) 

These don't require any runtime and should just run on the corresponding OS.

If go is installed you can build all three binaries on Linux using the make.sh script.  
Mac and Windows developers should be able to create a similar script.  
Note that you will need the [go install from golang.org](https://golang.org/doc/install) in order to be sure of creating static 
binaries.  The gccgo package that RedHat provides creates dynamically linked binaries that require a go runtime to be installed 
before they will run.
