// userManagement uses the IBM Security Verify APIs

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"
)

// Model for grant information
type PatchRequest struct {
	Operations []PatchOp `json:"Operations"`
	Schemas    []string  `json:"schemas"`
}

type PatchOp struct {
	Op    string `json:"op"`
	Path  string `json:"path"`
	Value string `json:"value"`
}

// disableUser calls the users API to disable the password for the userName
// See https://docs.verify.ibm.com/verify/reference/patchuser
func disableUser(configInfo *ConfigInfo, user string) (err error) {
	err = checkAuth(configInfo)
    if err != nil {
		return
    }
	patchRequest := PatchRequest{}
	patchOp := PatchOp{
		Op:    "replace",
		Path:  "password",
		Value: "{SHA256}passwordDisabled",
	}
	patchRequest.Operations = append(patchRequest.Operations, patchOp)
	patchRequest.Schemas = append(patchRequest.Schemas, "urn:ietf:params:scim:api:messages:2.0:PatchOp")
	patchBody, err := json.Marshal(patchRequest)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s marshalling patchRequest\n%v\n", err, patchRequest)
		failures++
		return
	}
	completeURL := "https://" + configInfo.tenantHostname + "/v2.0/Users/" + user
	if configInfo.logLevel > 0 {
		fmt.Printf("Calling %s\n", completeURL)
	}
	client := &http.Client{
		Timeout: time.Second * 200,
	}
	req, err := http.NewRequest("PATCH", completeURL, bytes.NewBuffer([]byte(patchBody)))
	if err != nil {
		fmt.Fprintf(os.Stderr, "Received error %s creating new request from URL %s\n", err, completeURL)
		failures++
		return
	}
	req.Header.Add("Authorization", "Bearer "+configInfo.accessToken)
	req.Header.Add("Accept", "application/scim+json")
	req.Header.Add("Content-Type", "application/scim+json")
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
	return
}
