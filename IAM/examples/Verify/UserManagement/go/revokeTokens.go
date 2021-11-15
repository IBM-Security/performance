// userManagement uses the IBM Security Verify APIs

package main

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"
)

// revokeTokens calls the revokeToken for each grant ID belonging to the username
// https://docs.verify.ibm.com/verify/reference/deletegrant_0
func revokeTokens(configInfo *ConfigInfo, user string) (err error) {
	idList, err := listTokens(configInfo, user)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s from listTokens of user %s on server %s\n", err, user, configInfo.tenantHostname)
		failures++
		return
	}
	if configInfo.logLevel > 0 {
		fmt.Printf("Got %d ids back\n", len(idList))
	}
	for i, id := range idList {
		if configInfo.logLevel > 0 {
			fmt.Printf("Revoking grant %d with id %s\n", i, id)
		}
		err := revokeToken(configInfo, user, id)
		if err != nil {
		} else {
			if configInfo.logLevel > 0 {
				fmt.Printf("Revoked token %d for user %s\n", i, user)
			}
		}
	}
	return
}

// revokeToken revokes the specified token for the specified user
func revokeToken(configInfo *ConfigInfo, user string, id string) (err error) {
	completeURL := "https://" + configInfo.tenantHostname + "/v1.0/grants/" + id
	if configInfo.logLevel > 0 {
		fmt.Printf("Calling %s\n", completeURL)
	}
	client := &http.Client{
		Timeout: time.Second * 200,
	}
	req, err := http.NewRequest("DELETE", completeURL, nil)
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

	if resp.StatusCode != 204 {
		fmt.Fprintf(os.Stderr, "Received response code %d from server %s\n%s\n", resp.StatusCode, configInfo.tenantHostname, contents)
		failures++
		return
	}

	if configInfo.logLevel > 1 {
		fmt.Printf("%s\n", contents)
	}
	successes++
	return
}
