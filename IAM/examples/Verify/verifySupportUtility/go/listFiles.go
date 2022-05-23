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

//listFiles lists the files already uploaded to the tenant
func listFiles(configInfo *ConfigInfo) (err error) {
	http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	serverURL := "https://" + configInfo.tenantHostname + configInfo.serverEndpoint + uploadPath
	if configInfo.logLevel > 0 {
		fmt.Printf("Connecting to " + configInfo.tenantHostname + configInfo.serverEndpoint + uploadPath + "\n")
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

    err = json.Unmarshal(contents, &fileListing)
    if err != nil {
        fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n %s", string(contents), err)
        return
    }

    fmt.Printf("Upload time                     Filename\tActual\tRequest\tStatus\tComment\n")
    for _, file := range fileListing {
        fmt.Printf("%s\t%s\t%d\t%d\t%s\t%s\n", time.Unix(file.ModTime,0), file.Filename, file.FileSize, file.UploadSize, file.Status, file.Comment)
    }
    
	return
}
