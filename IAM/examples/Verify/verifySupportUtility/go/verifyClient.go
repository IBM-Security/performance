// verifyClient uses the IBM Security Verify APIs

package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
    "time"
)

// Model for token information
type TokenInfo struct {
	AccessToken string `json:"access_token"`
	Scope       string `json:"scope"`
	GrantID     string `json:"grant_id"`
	IDToken     string `json:"id_token"`
	TokenType   string `json:"token_type"`
	ExpiresIn   int    `json:"expires_in"`
}

// doAuth calls the tenant's token endpoint with client and secret to get an access token
// See https://docs.verify.ibm.com/verify/reference/handletoken
func doAuth(configInfo *ConfigInfo) (err error) {
	var tokenInfo TokenInfo
	http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
	tokenEndpoint := "/v1.0/endpoint/default/token"
	completeURL := "https://" + configInfo.tenantHostname + tokenEndpoint
	if configInfo.logLevel > 0 {
		fmt.Printf("Calling %s\n", completeURL)
	}
	postBody := fmt.Sprintf("grant_type=client_credentials&client_id=%s&client_secret=%s&scope=openid", configInfo.tenantClient, configInfo.tenantSecret)
	resp, err := http.Post(completeURL, "application/x-www-form-urlencoded", bytes.NewBuffer([]byte(postBody)))
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

	err = json.Unmarshal(contents, &tokenInfo)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n ", string(contents))
		failures++
		return
	}

	configInfo.accessToken = tokenInfo.AccessToken
	configInfo.accessExpires = time.Now().Add(time.Second * time.Duration(tokenInfo.ExpiresIn))
	successes++
	return
}

// checkAuth refreshes the access token if it has expired
func checkAuth(configInfo *ConfigInfo) (err error) {
    if time.Now().After(configInfo.accessExpires) {
        err = doAuth(configInfo)
    }
    return
}
