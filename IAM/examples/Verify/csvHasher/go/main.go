// csvHasher converts the specified column of a CSV file to SHA256 format
// The format generated is consistent with https://docs.ldap.com/specs/draft-stroeder-hashed-userpassword-values-01.txt

package main

import (
	"crypto/sha256"
    "encoding/base64"
	"encoding/csv"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
)

type ConfigInfo struct {
	inputFileName  string
	outputFileName string
	logLevel       string
	hashColumn     int
}

func main() {
	configInfo := getArguments()
	inputCsvReader := openInputFile(configInfo.inputFileName)
	outputCsvWriter := openOutputFile(configInfo.outputFileName)
    recordCount := 0
	for {
		record, err := inputCsvReader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalln("error reading record from csv:", err)
		}
		recordCount++
		if recordCount > 1 {
		hashSpecifiedColumn(record, configInfo.hashColumn)
        }
		err = outputCsvWriter.Write(record)
		if err != nil {
			log.Fatalln("error writing record to csv:", err)
		}
	}
	outputCsvWriter.Flush()
	if err := outputCsvWriter.Error(); err != nil {
		log.Fatal(err)
	}
	return
}

//getArguments validates command line argument passed in
func getArguments() (configInfo ConfigInfo) {
	fs := flag.NewFlagSet("csvHasher", flag.ContinueOnError)
	inputFileName := fs.String("input_file", "", "Name of database snapshot file")
	outputFileName := fs.String("output_file", "", "Name of database analysis output files (defaults to stdout)")
	helpArg := fs.Bool("help", false, "Display the full help text")
	loglevelArg := fs.String("loglevel", "CRITICAL", "Logging Level (defaults to CRITICAL).")
	hashColumn := fs.Int("hash_column", 0, "column to hash")

	if err := fs.Parse(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "Usage csvHasher -input_file csv_file -output_file csv_file -hash_column column_number\n")
		os.Exit(1)
	}

	if *helpArg {
		doHelp()
	}

	if *inputFileName == "" {
		fmt.Fprintf(os.Stderr, "Error: missing input_file\n")
		fmt.Fprintf(os.Stderr, "Usage csvHasher -input_file csv_file -output_file csv_file -hash_column column_number\n")
		os.Exit(1)
	}
	if *outputFileName == "" {
		fmt.Fprintf(os.Stderr, "Error: missing output_file\n")
		fmt.Fprintf(os.Stderr, "Usage csvHasher -input_file csv_file -output_file csv_file -hash_column column_number\n")
		os.Exit(1)
	}
	if *hashColumn == 0 {
		fmt.Fprintf(os.Stderr, "Error: missing hash_column\n")
		fmt.Fprintf(os.Stderr, "Usage csvHasher -input_file csv_file -output_file csv_file -hash_column column_number\n")
		os.Exit(1)
	}

	configInfo.inputFileName = *inputFileName
	configInfo.outputFileName = *outputFileName
	configInfo.hashColumn = *hashColumn-1
	configInfo.logLevel = *loglevelArg

	return
}

// doHelp outputs detailed help message
func doHelp() {
	fmt.Printf("Usage csvHasher -input_file csv_file -output_file csv_file -hash_column column_number\n")
    fmt.Printf("   csvHasher converts the specified column of a CSV file to SHA256 format usable as an ldap password\n")
    fmt.Printf("   The format generated is consistent with https://docs.ldap.com/specs/draft-stroeder-hashed-userpassword-values-01.txt\n")

	os.Exit(0)
}

// openInputFile returns a csv reader for the specified file if it exists
func openInputFile(inputFileName string) (inputCsvReader *csv.Reader) {
	f, err := os.Open(inputFileName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error opening %s: %v \n ", inputFileName, err)
		os.Exit(1)
	}
	inputCsvReader = csv.NewReader(f)
	return
}

// openOutputFile returns a csv writer for the specified file if it can be created
func openOutputFile(outputFileName string) (outputCsvWriter *csv.Writer) {
	f, err := os.Create(outputFileName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error opening %s: %v \n ", outputFileName, err)
		os.Exit(1)
	}
	outputCsvWriter = csv.NewWriter(f)
	return
}

func hashSpecifiedColumn(record []string, hashColumn int) {
	if len(record) <= hashColumn {
		fmt.Fprintf(os.Stderr, "Record does not contain at least %d columns: %v \n ", hashColumn, record)
		os.Exit(1)
	}
	sum := sha256.Sum256([]byte(record[hashColumn]))
	record[hashColumn] = "{SHA256}"+base64.StdEncoding.EncodeToString(sum[:])
	return
}
