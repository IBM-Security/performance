package main

import (
	"database/sql"
	"flag"
	"fmt"
	_ "github.com/ibmdb/go_ibm_db"
	"os"
	"strings"
)

// Type for entry information
type ldapEntry struct {
	dn_trunc         string
	dn               string
	modify_timestamp string
}

var verbose = 0

func listAllEntries(DBconn *sql.DB, schema string, out chan<- ldapEntry) {
	defer close(out)
	listAllEntries := []string{
		"select dn_trunc, modify_timestamp ",
		"from %s.ldap_entry order by dn_trunc "}
	listAllEntriesSQLTemplate := strings.Join(listAllEntries, "")
	listAllEntriesSQL := fmt.Sprintf(listAllEntriesSQLTemplate, schema)
	statement, err := DBconn.Prepare(listAllEntriesSQL)
	if err != nil {
		fmt.Println("Error on Prepare: ", err.Error())
		return
	}
	rows, err := statement.Query()
	if err != nil {
		fmt.Println("Error on Query: ", err.Error())
		return
	}
	defer rows.Close()

	for rows.Next() {
		var dn_trunc, modify_timestamp string
		err = rows.Scan(&dn_trunc, &modify_timestamp)
		if err != nil {
			fmt.Println("Error on Scan: ", err.Error())
			return
		}
		out <- ldapEntry{dn_trunc, dn_trunc, modify_timestamp}
	}
	return
}

func compareAllEntryModifyTimestamps(firstDB *sql.DB, secondDB *sql.DB, schema1 string, schema2 string) error {
	fmt.Println("Reporting dn_trunc and modify_timestamp for any conflicting entries")
	fmt.Println("-------------------------------------------------------------------")

	ldap1Entries := make(chan ldapEntry)
	ldap2Entries := make(chan ldapEntry)

	go listAllEntries(firstDB, schema1, ldap1Entries)
	go listAllEntries(secondDB, schema2, ldap2Entries)

	ldap1Entry := <-ldap1Entries
	ldap2Entry := <-ldap2Entries

	for ldap1Entry.dn_trunc != "" && ldap2Entry.dn_trunc != "" {
		if verbose > 1 {
			fmt.Println("ldap1Entry: ", ldap1Entry.dn_trunc)
			fmt.Println("ldap2Entry: ", ldap2Entry.dn_trunc)
		}
		switch {
		case ldap1Entry.dn_trunc == ldap2Entry.dn_trunc:
			if ldap1Entry.modify_timestamp != ldap2Entry.modify_timestamp {
				fmt.Printf("Mismatching timestamps for %s: %s != %s\n", ldap1Entry.dn_trunc, ldap1Entry.modify_timestamp, ldap2Entry.modify_timestamp)
			}
			ldap1Entry = <-ldap1Entries
			ldap2Entry = <-ldap2Entries

		case ldap1Entry.dn_trunc < ldap2Entry.dn_trunc:
			fmt.Printf("Missing entry on second server: %s\n", ldap1Entry.dn_trunc)
			ldap1Entry = <-ldap1Entries

		case ldap1Entry.dn_trunc > ldap2Entry.dn_trunc:
			fmt.Printf("Missing entry on first server: %s\n", ldap2Entry.dn_trunc)
			ldap2Entry = <-ldap2Entries

		}
	}
	for ldap1Entry.dn_trunc != "" {
		fmt.Printf("Missing entry on second server: %s\n", ldap1Entry.dn_trunc)
		ldap1Entry = <-ldap1Entries
	}

	for ldap2Entry.dn_trunc != "" {
		fmt.Printf("Missing entry on first server: %s\n", ldap2Entry.dn_trunc)
		ldap2Entry = <-ldap2Entries
	}

	return nil
}

func CreateConn(con string) *sql.DB {
	db, err := sql.Open("go_ibm_db", con)
	if err != nil {
		fmt.Println(err)
		return nil
	}
	return db
}

func DoUsage(message string) {
	fmt.Println(strings.TrimSpace(`
usage: ldap_sdiff.go [-h] --dbname1 DBNAME [--hostname1 HOSTNAME]
                       [--port1 PORT] [--schema1 SCHEMA] [--userid1 USERID] --password1 PASSWORD
                       --dbname2 DBNAME [--hostname2 HOSTNAME]
                       [--port2 PORT] [--schema2 SCHEMA] [--userid2 USERID] --password2 PASSWORD
`))
	if message != "" {
		fmt.Println(message)
	}
	os.Exit(1)
}

func DoHelp() {
	fmt.Println(strings.TrimSpace(`
usage: ldap_sdiff.go [-h] --dbname1 DBNAME [--hostname1 HOSTNAME]
                       [--port1 PORT] [--schema1 SCHEMA] [--userid1 USERID] --password1 PASSWORD
                       --dbname2 DBNAME [--hostname2 HOSTNAME]
                       [--port2 PORT] [--schema2 SCHEMA] [--userid2 USERID] --password2 PASSWORD
Provide DB2 connection details to determine replication status.

optional arguments:
  -h, --help           show this help message and exit
  --dbname1 DBNAME      DB2 Database Name underlying LDAP.
  --hostname1 HOSTNAME  Hostname of LDAP server (defaults to localhost).
  --port1 PORT          Port# DB2 is listening on (defaults to 50000).
  --schema1 SCHEMA      DB2 Table name schema (defaults to userid).
  --userid1 USERID      Userid to connect to DB2 (defaults to dbname).
  --password1 PASSWORD  Password to connect to DB2.
  --dbname2 DBNAME      DB2 Database Name underlying LDAP.
  --hostname2 HOSTNAME  Hostname of LDAP server (defaults to localhost).
  --port2 PORT          Port# DB2 is listening on (defaults to 50000).
  --schema2 SCHEMA      DB2 Table name schema (defaults to userid).
  --userid2 USERID      Userid to connect to DB2 (defaults to dbname).
  --password2 PASSWORD  Password to connect to DB2.
`))
	os.Exit(1)
}

// Set to different things by who is building
var Version = "sandbox"

func main() {
	fs := flag.NewFlagSet("ldap_sdiff", flag.ContinueOnError)
	dbname1Arg := fs.String("dbname1", "", "DB2 Database Name underlying LDAP.")
	hostname1Arg := fs.String("hostname1", "localhost", "Hostname of LDAP server (defaults to localhost).")
	port1Arg := fs.Int("port1", 50000, "Port# DB2 is listening on (defaults to 50000).")
	schema1Arg := fs.String("schema1", "", "DB2 Table name schema (defaults to userid).")
	userid1Arg := fs.String("userid1", "", "Userid to connect to DB2 (defaults to dbname).")
	password1Arg := fs.String("password1", "", "Password to connect to DB2..")
	dbname2Arg := fs.String("dbname2", "", "DB2 Database Name underlying LDAP.")
	hostname2Arg := fs.String("hostname2", "localhost", "Hostname of LDAP server (defaults to localhost).")
	port2Arg := fs.Int("port2", 50000, "Port# DB2 is listening on (defaults to 50000).")
	schema2Arg := fs.String("schema2", "", "DB2 Table name schema (defaults to userid).")
	userid2Arg := fs.String("userid2", "", "Userid to connect to DB2 (defaults to dbname).")
	password2Arg := fs.String("password2", "", "Password to connect to DB2..")
	verboseArg := fs.Int("verbose", 0, "Level of debugging (defaults to 0 - none).")
	help := fs.Bool("help", false, "Display the full help text")

	if err := fs.Parse(os.Args[1:]); err != nil {
		os.Exit(1)
	}

	if *help {
		DoHelp()
	}

	if *dbname2Arg == "" || *password2Arg == "" || *dbname1Arg == "" || *password1Arg == "" {
		requiredArguments := ""
		if *dbname1Arg == "" {
			requiredArguments += " --dbname1"
		}
		if *password1Arg == "" {
			requiredArguments += " --password1"
		}
		if *dbname2Arg == "" {
			requiredArguments += " --dbname2"
		}
		if *password2Arg == "" {
			requiredArguments += " --password2"
		}
		message := fmt.Sprintf("%s: error: the following arguments are required: %s\n", os.Args[0], requiredArguments)
		DoUsage(message)
	}

	verbose = *verboseArg

	userid1 := *userid1Arg
	if *userid1Arg == "" {
		userid1 = *dbname1Arg
	}
	schema1 := *schema1Arg
	if schema1 == "" {
		schema1 = *userid1Arg
	}

	userid2 := *userid2Arg
	if *userid2Arg == "" {
		userid2 = *dbname2Arg
	}
	schema2 := *schema2Arg
	if schema2 == "" {
		schema2 = *userid2Arg
	}

	firstConnectionString := fmt.Sprintf("HOSTNAME=%s;DATABASE=%s;PORT=%d;UID=%s;PWD=%s", *hostname1Arg, *dbname1Arg, *port1Arg, userid1, *password1Arg)
	secondConnectionString := fmt.Sprintf("HOSTNAME=%s;DATABASE=%s;PORT=%d;UID=%s;PWD=%s", *hostname2Arg, *dbname2Arg, *port2Arg, userid2, *password2Arg)

	type Db *sql.DB
	var firstConn Db
	firstConn = CreateConn(firstConnectionString)
	if firstConn == nil {
		fmt.Printf("Unable to connect successfully to %s!", firstConnectionString)
		os.Exit(1)
	}
	var secondConn Db
	secondConn = CreateConn(secondConnectionString)
	if secondConn == nil {
		fmt.Printf("Unable to connect successfully to %s!", secondConnectionString)
		os.Exit(1)
	}
	err := compareAllEntryModifyTimestamps(firstConn, secondConn, schema1, schema2)
	if err != nil {
		fmt.Println(err)
	}
}
