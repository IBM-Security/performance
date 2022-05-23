package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"
	"time"
)

//listResults lists the results for files already uploaded to the tenant
func listResults(configInfo *ConfigInfo) (err error) {
	http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	serverURL := "https://" + configInfo.tenantHostname + configInfo.serverEndpoint + resultsPath
	if configInfo.resultsFile != "" {
        serverURL = serverURL + "/" + configInfo.resultsFile
    }
	if configInfo.logLevel > 0 {
		fmt.Printf("Connecting to " + configInfo.tenantHostname + configInfo.serverEndpoint + resultsPath + "\n")
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
            
    var fileListing FileListing
    if configInfo.logLevel > 1 {
        fmt.Printf("%s\n", string(contents))
    }

    	if configInfo.resultsFile != "" {
fmt.Printf("%s\n", string(contents))
return
    }
    
    err = json.Unmarshal(contents, &fileListing)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n %s", string(contents), err)
        return
    }

    fmt.Printf("Results time                     Filename\tStatus\tComment\tId\n")
    for _, file := range fileListing {
        fmt.Printf("%s\t%s\t%s\t%s\t%s\n", time.Unix(file.ModTime,0),file.Filename, file.Status, file.Comment, file.Id)
    }
    
	return
}
