package main

import (
	"flag"
	"fmt"
	"os"
	"regexp"
    "strings"
	"time"
)

const (
	uploadPath = "/v1.0/uploads/"
	resultsPath = "/v1.0/results/"
    statusPath = "/v1.0/status/health/"
)

type ConfigInfo struct {
	accessToken    string
	accessExpires  time.Time
	command        string
	logLevel       int
	resultsFile    string
	tenantURL      string
	tenantHostname string
	tenantClient   string
	tenantSecret   string
	uploadFile     string
	uploadComment  string
	serverEndpoint string
}

type FileListing []uploadInfo 

type uploadInfo struct {
    Id         string `json:"id"`
	ModTime    int64  `json:"modtime"`
	Filename   string `json:"filename"`
	FileSize   int    `json:"filesize"`
	UploadSize int    `json:"uploadSize"`
	Status     string `json:"status"`
	Comment    string `json:"comment"`
}

var successes, failures int

func main() {
	configInfo := getArguments()
	if configInfo.logLevel >= 1 {
		fmt.Printf("Command: %s\nURL: %s\nuploadFile: %s\n", configInfo.command, configInfo.tenantURL, configInfo.uploadFile)
		fmt.Printf("Host: %s\nClient: %s\nSecret: %s\n", configInfo.tenantHostname, configInfo.tenantClient, configInfo.tenantSecret)
	}

	err := doAuth(&configInfo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error authenticating to %s: %v \n ", configInfo.tenantURL, err)
		os.Exit(1)
	}
	if configInfo.logLevel >= 1 {
		fmt.Printf("Got accessToken %s\n", configInfo.accessToken)
	}

	if configInfo.command == "auth" {
        fmt.Printf("Successfully authenticated to %s\n", configInfo.tenantHostname)
        os.Exit(0)
    }
    
	err, status := getEndpoint(&configInfo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting server status from %s: %v \n ", configInfo.tenantHostname, err)
		os.Exit(1)
	}
    
	if configInfo.logLevel >= 1 {
		fmt.Printf("Received status %s from server\n", status)
	}
    if configInfo.command == "status" {
        fmt.Printf("Service is responding\n")
        if strings.Contains(status,"good") {
            fmt.Printf("Status is good\n")
        }
        os.Exit(0)
    }
    
	if configInfo.command != "" {
		switch configInfo.command {

		case "upload":
			err = uploadFile(&configInfo)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Received error %s from uploadFile of %s on server %s\n", err, configInfo.uploadFile, configInfo.tenantHostname)
				failures++
			} else {
				fmt.Printf("Successfully uploaded %s\n", configInfo.uploadFile)
			}

		case "list":
			err = listFiles(&configInfo)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Received error %s from listFiles on server %s\n", err, configInfo.tenantHostname)
				failures++
			}

		case "results":
			err = listResults(&configInfo)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Received error %s from listResults on server %s\n", err, configInfo.tenantHostname)
				failures++
			}

		default:
			fmt.Printf("Received unrecognized command: %s\n", configInfo.command)

		}
	}

	if failures > 0 {
        os.Exit(1)
	}
	return
}


//getArguments validates command line argument passed in.
func getArguments() (configInfo ConfigInfo) {
	fs := flag.NewFlagSet("verifySupportUtility", flag.ExitOnError)
	tenantURL := fs.String("tenantURL", "", "URL used to contact tenant: client:secret@tenant.domain")
	resultsFile := fs.String("resultsFile", "", "Optional results file to download from Verify")
	uploadFile := fs.String("uploadFile", "", "Optional file to upload to Verify")
	uploadComment := fs.String("uploadComment", "", "Optional comment to include with upload to Verify")
	helpArg := fs.Bool("help", false, "Display the full help text")
	loglevelArg := fs.Int("loglevel", 0, "Logging Level (defaults to 0).")

	fs.Usage = printUsage

	if len(os.Args) == 1 {
		printUsage()
		os.Exit(1)
	}

	configInfo.command = os.Args[1]

	if len(os.Args) > 2 {
		if err := fs.Parse(os.Args[2:]); err != nil {
			printUsage()
			os.Exit(1)
		}
	}

	if *helpArg || *tenantURL == "" || configInfo.command == "-help" || configInfo.command == "help" {
		printUsage()
		os.Exit(0)
	}

	if configInfo.command == "upload" && *uploadFile == "" {
		fmt.Fprintf(os.Stderr, "The upload operation requires an uploadFile\n ")
		os.Exit(1)
	}

	configInfo.tenantURL = *tenantURL

	tenantRegex := regexp.MustCompile("^(.+):(.+)@(.+)$")
	matches := tenantRegex.FindStringSubmatch(configInfo.tenantURL)

	if len(matches) < 4 {
		fmt.Fprintf(os.Stderr, "tenantURL %s is not in the format client:secret@tenant.domain\n ", configInfo.tenantURL)
		os.Exit(1)
	}

	configInfo.tenantClient = matches[1]
	configInfo.tenantSecret = matches[2]
	configInfo.tenantHostname = matches[3]

	configInfo.resultsFile = *resultsFile
	configInfo.uploadFile = *uploadFile
	configInfo.uploadComment = *uploadComment
	configInfo.logLevel = *loglevelArg

	return
}

//printUsage prints out the usage statement
func printUsage() {
	fmt.Fprintf(os.Stderr, "Usage: verifySupportUtility [auth|status|upload|list|results|help] -tenantURL tenantURL [-uploadFile filename] [-uploadComment comment] [-resultsFile filename]\n")
	fmt.Fprintf(os.Stderr, "Usage of verifySupportUtility:\n")
	fmt.Fprintf(os.Stderr, "        command is one of [ auth, status, upload, list, results, help ]\n")
	fmt.Fprintf(os.Stderr, "        (default is 'help')\n")
	fmt.Fprintf(os.Stderr, "  -help\n")
	fmt.Fprintf(os.Stderr, "        Display the full help text\n")
	fmt.Fprintf(os.Stderr, "  -loglevel integer\n")
	fmt.Fprintf(os.Stderr, "        Logging Level (default 0)\n")
	fmt.Fprintf(os.Stderr, "        0=report success/failure, status codes, response times  (default)\n")
	fmt.Fprintf(os.Stderr, "        1=report include response body\n")
	fmt.Fprintf(os.Stderr, "        2=report include request body\n")
	fmt.Fprintf(os.Stderr, "        3=report full trace (for debugging)\n")
	fmt.Fprintf(os.Stderr, "  -tenantURL tenantURL\n")
	fmt.Fprintf(os.Stderr, "        URL used to contact tenant: client:secret@tenant.domain\n")
	fmt.Fprintf(os.Stderr, "  -uploadFile filename\n")
	fmt.Fprintf(os.Stderr, "        Optional file to upload to Verify\n")
	fmt.Fprintf(os.Stderr, "  -uploadComment comment\n")
	fmt.Fprintf(os.Stderr, "        Optional comment to include with upload to Verify\n")
	fmt.Fprintf(os.Stderr, "  -resultsFile filename\n")
	fmt.Fprintf(os.Stderr, "        Optional results file to download from Verify\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "auth\tAuthenticate to the tenant using the specified client and secret\n")
	fmt.Fprintf(os.Stderr, "status\tQuery status of the file upload service\n")
	fmt.Fprintf(os.Stderr, "upload\tUpload the specified uploadFile to Verify\n")
	fmt.Fprintf(os.Stderr, "list\tList uploaded files\n")
	fmt.Fprintf(os.Stderr, "results\tList any results or download a results file\n")
	fmt.Fprintf(os.Stderr, "help\tDisplay the full help text\n")
}
