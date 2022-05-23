package main

import (
	"crypto/tls"
    "errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
)

func getEndpoint(configInfo *ConfigInfo) (err error, status string) {
	if configInfo.logLevel > 0 {
        fmt.Printf("Checking status with endpoint /support\n")
    }
    configInfo.serverEndpoint = "/support"
    err, status = listStatus(configInfo)
    if err == nil && status != "" {
        return
    }
	if configInfo.logLevel > 0 {
        fmt.Printf("Checking status with endpoint /files\n")
    }
    configInfo.serverEndpoint = "/files"
    err, status = listStatus(configInfo)
    return
}
    
//listStatus lists the status of the support server
func listStatus(configInfo *ConfigInfo) (err error, status string) {
	http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	serverURL := "https://" + configInfo.tenantHostname + configInfo.serverEndpoint + statusPath
	if configInfo.logLevel > 0 {
		fmt.Printf("Connecting to " + serverURL + "\n")
	}
	client := &http.Client{}
	request, err := http.NewRequest("GET", serverURL, strings.NewReader(""))
	request.Header.Set("Authorization", "Bearer "+configInfo.accessToken)
	request.ContentLength = 0
	resp, err := client.Do(request)

	if err != nil {
		return
	}
	defer resp.Body.Close()

	contents, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return
	}

	if resp.StatusCode != 200 {
		fmt.Fprintf(os.Stderr, "Received response code %d from server\n%s\n", resp.StatusCode, contents)
		os.Exit(1)
	}

	if configInfo.logLevel >= 2 {
		printHeaders(resp.Header)
	}

	contentTypeFound := false
	if resp.Header["Content-Type"] != nil {
        for _, value := range resp.Header["Content-Type"] {
            if value == "application/json" {
              contentTypeFound = true
            }
		}
    }
    
    if contentTypeFound==false {
        err = errors.New("Invalid status returned")
    }
    
    status = string(contents)
    
	return
}

func printHeaders(headers http.Header) {
	for name, values := range headers {
		for _, value := range values {
			fmt.Printf("%s: %s\n", name, value)
		}
	}
}
