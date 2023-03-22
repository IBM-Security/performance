// csvHasher converts the specified column of a CSV file to SHA256 format
// The format generated is consistent with https://docs.ldap.com/specs/draft-stroeder-hashed-userpassword-values-01.txt

package main

import (
	"crypto/sha256"
	"crypto/sha512"
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
	ColumnName     string
	ColumnNumber   int
	HashSize       int
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
		if recordCount == 1 {
			if configInfo.ColumnName != "" {
				getColumnNumber(&configInfo, record)
			}
		} else {
			if configInfo.HashSize == 512 {
				hash512SpecifiedColumn(record, configInfo.ColumnNumber)
			} else {
				hash256SpecifiedColumn(record, configInfo.ColumnNumber)
			}
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
	ColumnName := fs.String("column_name", "", "column to hash")
	ColumnNumber := fs.Int("column_number", 0, "column to hash")
	HashSize := fs.Int("hash_size", 256, "Hash size (defaults to 256)")

	UsageString := "Usage csvHasher -input_file csv_file -output_file csv_file [-column_name column_name | -column_number column_number] [-hash_size 256 | 512]\n"

	if err := fs.Parse(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, UsageString)
		os.Exit(1)
	}

	if *helpArg {
		doHelp()
	}

	if *inputFileName == "" {
		fmt.Fprintf(os.Stderr, "Error: missing input_file\n")
		fmt.Fprintf(os.Stderr, UsageString)
		os.Exit(1)
	}
	if *outputFileName == "" {
		fmt.Fprintf(os.Stderr, "Error: missing output_file\n")
		fmt.Fprintf(os.Stderr, UsageString)
		os.Exit(1)
	}
	if *ColumnNumber == 0 && *ColumnName == "" {
		fmt.Fprintf(os.Stderr, "Error: missing hash column name and number\n")
		fmt.Fprintf(os.Stderr, UsageString)
		os.Exit(1)
	}

	configInfo.inputFileName = *inputFileName
	configInfo.outputFileName = *outputFileName
	if *ColumnNumber != 0 {
		configInfo.ColumnNumber = *ColumnNumber - 1
	}
	configInfo.ColumnName = *ColumnName
	configInfo.logLevel = *loglevelArg

	switch *HashSize {

	case 256:
		configInfo.HashSize = 256

	case 512:
		configInfo.HashSize = 512

	default:
		fmt.Fprintf(os.Stderr, "Error: HashSize must be 256 or 512\n")
		fmt.Fprintf(os.Stderr, UsageString)
		os.Exit(1)
	}
	return
}

// doHelp outputs detailed help message
func doHelp() {
	fmt.Printf("Usage csvHasher -input_file csv_file -output_file csv_file [-column_name column_name | -column_number column_number] [-hash_size 256 | 512]\n")
	fmt.Printf("   csvHasher converts the specified column of a CSV file to SHA256 or SHA512 format usable as an ldap password\n")
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

// getColumnNumber looks for ColumnName in the header record
func getColumnNumber(configInfo *ConfigInfo, record []string) {
	for i, name := range record {
		if name == configInfo.ColumnName {
			configInfo.ColumnNumber = i
		}
	}
	return
}

// hash256SpecifiedColumn replaces the specified column with the SHA256 hash
func hash256SpecifiedColumn(record []string, ColumnNumber int) {
	if len(record) <= ColumnNumber {
		fmt.Fprintf(os.Stderr, "Record does not contain at least %d columns: %v \n ", ColumnNumber, record)
		os.Exit(1)
	}
	sum := sha256.Sum256([]byte(record[ColumnNumber]))
	record[ColumnNumber] = "{SHA256}" + base64.StdEncoding.EncodeToString(sum[:])
	return
}

// hash512SpecifiedColumn replaces the specified column with the SHA512 hash
func hash512SpecifiedColumn(record []string, ColumnNumber int) {
	if len(record) <= ColumnNumber {
		fmt.Fprintf(os.Stderr, "Record does not contain at least %d columns: %v \n ", ColumnNumber, record)
		os.Exit(1)
	}
	sum := sha512.Sum512([]byte(record[ColumnNumber]))
	record[ColumnNumber] = "{SHA512}" + base64.StdEncoding.EncodeToString(sum[:])
	return
}
