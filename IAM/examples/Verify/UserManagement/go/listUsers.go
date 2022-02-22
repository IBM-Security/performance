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

// listUsers calls the getusers API to iterate through the users
// See https://docs.verify.ibm.com/verify/reference/getusers
func listUsers(configInfo *ConfigInfo) (err error) {
	usersReturned := 0
	err, userList := getUserList(configInfo, "id", "", "id,meta.created,emails,urn:ietf:params:scim:schemas:extension:ibm:2.0:User:realm,meta.created,emails,urn:ietf:params:scim:schemas:extension:ibm:2.0:User:lastLogin")
	if err != nil {
		fmt.Printf("Error %s from getUserList\n", err)
	}
	for len(userList.Resources) > 0 {
		usersReturned += len(userList.Resources)
        fmt.Printf("Got %d users back\n", len(userList.Resources))
		err, userId := filterUserList(configInfo, userList)
		if err != nil {
			fmt.Printf("Error %s from filterUserList\n", err)
		}
		nextUserId := userId + "0"
		err, userList = getUserList(configInfo, "id", nextUserId, "id,meta.created,emails,urn:ietf:params:scim:schemas:extension:ibm:2.0:User:realm,meta.created,emails,urn:ietf:params:scim:schemas:extension:ibm:2.0:User:lastLogin")
		if err != nil {
			fmt.Printf("Error %s from getUserList\n", err)
		}
	}
	fmt.Printf("%d users returned and filtered\n", usersReturned)
	return
}

// getUserList returns the next set of users after userStartingValue
func getUserList(configInfo *ConfigInfo, userAttribute, userStartingValue, attributeList string) (err error, userList UserList) {
	err = checkAuth(configInfo)
	if err != nil {
		return
	}
	userEndpoint := "/v2.0/Users"
	userQuery := "?filter=" + userAttribute + "%20ge%20%22" + userStartingValue + "%22"
	sortBy := "&sortBy=" + userAttribute
	attributes := ""
	if attributeList != "" {
		attributes = "&attributes=" + attributeList
	}
	countLimit := "&count=2500"
	completeURL := "https://" + configInfo.tenantHostname + userEndpoint + userQuery + sortBy + attributes + countLimit
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

	err = json.Unmarshal(contents, &userList)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error trying to unmarshal response: \n%s \n ", string(contents))
		failures++
		return
	}
	return
}

// filterUserList processes a set of users, returning the last userId processed
func filterUserList(configInfo *ConfigInfo, userList UserList) (err error, userId string) {
	for _, user := range userList.Resources {
		if configInfo.logLevel > 1 {
			userResources, err := json.MarshalIndent(user, "", "\t")
			if err == nil {
				fmt.Printf("userResources is %s\n", userResources)
			}
		}
		userId = user["id"].(string)
		if user["urn:ietf:params:scim:schemas:extension:ibm:2.0:User"] == nil {
			email := ""
			if user["emails"] != nil {
				email = user["emails"].([]interface{})[0].(map[string]interface{})["value"].(string)
			}
			created := user["meta"].(map[string]interface{})["created"]
			fmt.Printf("user %s, %s created on %s has no lastLogin or realm\n", userId, email, created)
			continue
		}
		lastLogin := user["urn:ietf:params:scim:schemas:extension:ibm:2.0:User"].(map[string]interface{})["lastLogin"]
		realm := user["urn:ietf:params:scim:schemas:extension:ibm:2.0:User"].(map[string]interface{})["realm"]
		if lastLogin == nil && realm == "cloudIdentityRealm" {
			email := ""
			if user["emails"] != nil {
				email = user["emails"].([]interface{})[0].(map[string]interface{})["value"].(string)
			}
			created := user["meta"].(map[string]interface{})["created"]
			fmt.Printf("user %s, %s created on %s has no lastLogin\n", userId, email, created)
		}
	}
	return
}
