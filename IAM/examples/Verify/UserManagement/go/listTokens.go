// userManagement uses the IBM Security Verify APIs

package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"
)

// Model for grant information
type GrantList struct {
	Count  int         `json:"count"`
	Limit  int         `json:"limit"`
	Page   int         `json:"page"`
	Total  int         `json:"total"`
	Grants []GrantInfo `json:"grants"`
}

type GrantInfo map[string]interface{}

// listTokens calls the grants API for the username and returns all grant ids
// See https://docs.verify.ibm.com/verify/reference/readgrants_0
func listTokens(configInfo *ConfigInfo, user string) (idList []string, err error) {
	var grantList GrantList
	err = checkAuth(configInfo)
    if err != nil {
		return
    }
	grantEndpoint := "/v1.0/grants"
	userQuery := "?search=username%3D%22" + user + "%22"
	completeURL := "https://" + configInfo.tenantHostname + grantEndpoint + userQuery
	if configInfo.logLevel > 0 {
		fmt.Printf("Calling %s\n", completeURL)
	}
	client := &http.Client{
		Timeout: time.Second * 200,
	}
	req, err := http.NewRequest("GET", completeURL, nil)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s creating new request from URL %s\n", err, completeURL)
		failures++
		return
	}
	req.Header.Add("Authorization", "Bearer "+configInfo.accessToken)
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s from server\n%s\n", err, configInfo.tenantHostname)
		failures++
		return
	}
	defer resp.Body.Close()

	if configInfo.logLevel > 0 {
		fmt.Printf("Received %d from %s\n", resp.StatusCode, configInfo.tenantHostname)
	}

	contents, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s from server\n%s\n", err, configInfo.tenantHostname)
		failures++
		return
	}

	if resp.StatusCode != 200 {
		fmt.Fprintf(os.Stderr, "Received response code %d from server %s\n%s\n", resp.StatusCode, configInfo.tenantHostname, contents)
		failures++
		return
	}

	if configInfo.logLevel > 1 {
		fmt.Printf("%s\n", contents)
	}

	err = json.Unmarshal(contents, &grantList)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n ", string(contents))
		failures++
		return
	}
	for _, grant := range grantList.Grants {
		if configInfo.logLevel > 0 {
			fmt.Printf("Adding grant id %s to list\n", grant["id"])
		}
		idList = append(idList, grant["id"].(string))
	}
	successes++
	return
}
