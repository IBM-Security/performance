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

// Model for user information
type UserList struct {
	ItemsPerPage int        `json:"itemsPerPage"`
	StartIndex   int        `json:"startIndex"`
	Page         int        `json:"page"`
	TotalResults int        `json:"totalResults"`
	Resources    []UserInfo `json:"Resources"`
}

type UserInfo map[string]interface{}

// lookupUser calls the getusers API to lookup the user
func lookupUser(configInfo ConfigInfo, user string) (userName string, err error) {
	var userList UserList
	userEndpoint := "/v2.0/Users"
	userQuery := "?filter=" + configInfo.userAttribute + "%20eq%20%22" + user + "%22"
	completeURL := "https://" + configInfo.tenantHostname + userEndpoint + userQuery
	if configInfo.logLevel > 0 {
		fmt.Printf("Calling %s\n", completeURL)
	}
	client := &http.Client{
		Timeout: time.Second * 200,
	}
	req, err := http.NewRequest("GET", completeURL, nil)
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
	successes++

	err = json.Unmarshal(contents, &userList)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n ", string(contents))
		panic(err)
	}
	if len(userList.Resources) > 0 {
	userName = userList.Resources[0]["id"].(string)
    }
	return
}