// userManagement uses the IBM Security Verify APIs

package main

import (
	"bufio"
	"flag"
	"fmt"
	"os"
	"regexp"
	"strings"
    "time"
)

type ConfigInfo struct {
	accessToken    string
	accessExpires  time.Time
	command        string
	logLevel       int
	tenantURL      string
	tenantHostname string
	tenantClient   string
	tenantSecret   string
	userFile       string
	userAttribute  string
	userList       []string
}

var successes, failures int

func main() {
	var err error
	configInfo := getArguments()
	if configInfo.logLevel >= 1 {
		fmt.Printf("Command: %s\nURL: %s\nuserFile: %s\n", configInfo.command, configInfo.tenantURL, configInfo.userFile)
		fmt.Printf("Host: %s\nClient: %s\nSecret: %s\n", configInfo.tenantHostname, configInfo.tenantClient, configInfo.tenantSecret)
	}
	if configInfo.userFile != "" {
		configInfo.userList = getUsers(&configInfo)
	}
	if configInfo.logLevel >= 1 {
		fmt.Printf("Total users: %d\n", len(configInfo.userList))
	}
	err = doAuth(&configInfo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error authenticating to %s: %v \n ", configInfo.tenantURL, err)
		os.Exit(1)
	}
	if configInfo.logLevel >= 1 {
		fmt.Printf("Got accessToken %s\n", configInfo.accessToken)
	}

	if configInfo.userAttribute != "" {
		var userList []string
		for _, user := range configInfo.userList {
			username, err := lookupUser(&configInfo, user)
			if err == nil {
				userList = append(userList, username)
			}
		}
		configInfo.userList = userList
	}

	if configInfo.command != "" {
		switch configInfo.command {

		case "auth":

		case "listTokens":
			for _, user := range configInfo.userList {
				idList, err := listTokens(&configInfo, user)
				if err != nil {
					fmt.Fprintf(os.Stderr, "Received error %s from listTokens of user %s on server %s\n", err, user, configInfo.tenantHostname)
					failures++
				} else {
					if configInfo.logLevel >= 1 {
						fmt.Printf("Got %d ids back\n", len(idList))
					}
				}
			}

		case "revokeTokens":
			for _, user := range configInfo.userList {
				revokeTokens(&configInfo, user)
			}

		case "disableUser":
			for _, user := range configInfo.userList {
				disableUser(&configInfo, user)
			}

		default:
			fmt.Printf("Received unrecognized command: %s\n", configInfo.command)

		}
	}

	return
}

//getArguments validates command line argument passed in.
func getArguments() (configInfo ConfigInfo) {
	fs := flag.NewFlagSet("userManagement", flag.ExitOnError)
	tenantURL := fs.String("tenantURL", "", "URL used to contact tenant: client:secret@tenant.domain")
	userFile := fs.String("userFile", "", "Optional file containing list of users")
	userAttribute := fs.String("userAttribute", "", "The attribute referred to by the list of users (default userid)")
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

	configInfo.userFile = *userFile
	configInfo.logLevel = *loglevelArg
	configInfo.userList = []string{}
	configInfo.userAttribute = *userAttribute

	return
}

//printUsage prints out the usage statement
func printUsage() {
	fmt.Fprintf(os.Stderr, "Usage: userManagement [auth|listTokens|revokeTokens|disableUser|help] -tenantURL tenantURL [-userFile filename] [-userAttribute attributename]\n")
	fmt.Fprintf(os.Stderr, "Usage of userManagement:\n")
	fmt.Fprintf(os.Stderr, "        command is one of [ auth, listTokens, revokeTokens, disableUser, help ]\n")
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
	fmt.Fprintf(os.Stderr, "  -userFile filename\n")
	fmt.Fprintf(os.Stderr, "        Optional file containing a list of users\n")
	fmt.Fprintf(os.Stderr, "  -userAttribute attributename\n")
	fmt.Fprintf(os.Stderr, "        The attribute referred to by the list of users (default userid)\n")
	fmt.Fprintf(os.Stderr, "\n")
	fmt.Fprintf(os.Stderr, "auth\t\tAuthenticate to the tenant using the specified client and secret\n")
	fmt.Fprintf(os.Stderr, "listTokens\tList tokens for each user in the userFile\n")
	fmt.Fprintf(os.Stderr, "revokeTokens\tRevoke tokens for each user in the userFile\n")
	fmt.Fprintf(os.Stderr, "disableUser\tDisable each user in the userFile\n")
	fmt.Fprintf(os.Stderr, "help\t\tDisplay the full help text\n")
}

//getUsers opens userFile
func getUsers(configInfo *ConfigInfo) (userList []string) {
	var err error
	var userline string
	r := os.Stdin
	if configInfo.userFile != "" {
		r, err = os.Open(configInfo.userFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error opening %s: %v \n ", configInfo.userFile, err)
			os.Exit(1)
		}
	}
	userReader := bufio.NewReader(r)
	userline, err = userReader.ReadString('\n')
	for err == nil {
		userList = append(userList, strings.TrimRight(userline, "\n"))
		userline, err = userReader.ReadString('\n')
	}
	return
}
