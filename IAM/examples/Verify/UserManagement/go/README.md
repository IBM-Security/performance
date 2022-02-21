# IBM Security Performance

## Verify - Identity and Access Management

### Verify example - User Management

This directory contains Golang example code for bulk management of users using the Verify APIs.  The userManagement program performs
actions on a set of users, including listing tokens, revoking tokens and disabling the users by setting the password
to an unmatchable hash. 

### Table of Contents

* [Documentation of the APIs](#documentation-of-the-apis)
  * [Create an API client](#create-an-api-client)
  * [Get an access token](#get-an-access-token)
  * [Lookup users](#lookup-users)
  * [Lookup grants](#lookup-grant)
  * [Delete grant](#delete-grant)
  * [Modify password](#modify-password)
  * [List users](#list-users)
* [Usage of the example](#usage-of-the-example)
* [Building the example](#building-the-example)
* [Descriptions of the example files](#descriptions-of-the-example-files)

### Documentation of the APIs

The [IBM Security Verify Documentation Hub](https://docs.verify.ibm.com/verify/) provides
comprehensive guides and documentation to help you start working with IBM Security Verify as quickly as possible, 
as well as support if you get stuck. 

Of particular interest for these examples are the [Getting Started](https://docs.verify.ibm.com/verify/docs/guides)
guides and most importantly the [API Documentation](https://docs.verify.ibm.com/verify/page/api-documentation), since the example code
is calling a series of APIs.

#### Create an API client

The Getting Started page for [Create an API client](https://docs.verify.ibm.com/verify/docs/create-api-client) describes
how to create an API client with the appropriate accesses.  The set of accesses that you need to call each API is described in
the documentation for that API. 
* For [Get Users](https://docs.verify.ibm.com/verify/reference/getusers) the entitlement required is readUserGroups (Read users and groups) or manageUserGroups (Manage users and groups) or manageAllUserGroups (Synchronize users and groups) or manageUserStandardGroups (Manage users and standard groups).
  Note: You only need one entitlement, but you can have more than one.
* For [Read Grants](https://docs.verify.ibm.com/verify/reference/readgrants_0) the entitlement required is readOidcGrants (Read OIDC and OAuth grants) or manageOidcGrants (Manage OIDC and OAuth grants)
* For [Delete Grant](https://docs.verify.ibm.com/verify/reference/deletegrant) the entitlement required is manageOidcGrants (Manage OIDC and OAuth grants)
* For [Patch User](https://docs.verify.ibm.com/verify/reference/patchuser) the entitlement required is manageUserGroups (Manage users and groups) or manageAllUserGroups (Synchronize users and groups) or manageUserStandardGroups (Manage users and standard groups) or updateAnyUser (Update any user).

A minimal set that would be just enough for calling all four APIs would be readUserGroups, manageOidcGrants and updateAnyUser.

#### Get an access token

The first thing any program will need to do before calling the APIs is to get an access token, which it will later pass on
each API it calls.  The Getting Started page for [Client Credentials](https://docs.verify.ibm.com/verify/docs/get-an-access-token)
describes getting the access token for making API calls, using the client ID and secret that were generated when you
created the API client. Access tokens have a limited lifetime so it is important for a long-running program to ensure it does not 
use an expired access token.

The API documentation [Get the access token](https://docs.verify.ibm.com/verify/reference/handletoken) page is the 
API reference for that call.  Each page describes what the API does, what each of the input parameters and form data fields
is, along with the types and allowable values.  On the right-hand side of the page is example code in 16 languages 
plus curl command line examples, along with examples of successful and unsuccessful responses. 

As you read through the key functions in the example code, you can compare them to the Go example code in the API documentation.
The access token is retrieved in [doAuth.go](doAuth.go) in the doAuth() function.  It is checked for expiration and refreshed in
the checkAuth() function.

#### Lookup users

The API documentation [Get Users](https://docs.verify.ibm.com/verify/reference/getusers) page describes how to search
for specific users.  The userManagement example uses this to look up the information provided, such as username or
email, to get the user id for each user to pass in subsequent calls.

The user lookup code is in [lookupUser.go](lookupUser.go) in the lookupUser() function.

#### Lookup grants

The API documentation [Read Grants](https://docs.verify.ibm.com/verify/reference/readgrants_0) page describes how to
retrieve a list of grants associated with a specific userid. The userManagement example uses this to look up the grants
associated with the userid that was returned by lookupUser().

The grant lookup code is in [listTokens.go](listTokens.go) in the listTokens() function.

#### Delete grant

The API documentation [Delete Grant](https://docs.verify.ibm.com/verify/reference/deletegrant) page describes how to
delete a specific grant. The userManagement example uses this to delete each grant that was returned by listTokens(). 

The grant deletion code is in [revokeTokens.go](revokeTokens.go) in the revokeTokens() function.

#### Modify password

The API documentation [Patch User](https://docs.verify.ibm.com/verify/reference/patchuser) page describes how to
modify attributes for a specific user. The userManagement example uses this to change the password for the user id that was
returned by lookupUser(). Setting the password to an invalid hash ensures that the user will have to go through the password
reset process before that user id can authenticate. Changing the user's password also causes existing tokens to be revoked.

The user modify code is in [disableUser.go](disableUser.go) in the disableUser() function.

#### List users

The API documentation [Get Users](https://docs.verify.ibm.com/verify/reference/getusers) page describes how to search
for a set of users.  The userManagement example uses this to look up all users in the tenant, in order of id, to look for any
users without a lastLogin attribute, meaning the user has not logged in since the account was created.

The user list code is in [listUsers.go](listUsers.go) in the listUsers() function.

### Usage of the example
```text
Usage: userManagement [auth|listTokens|listUsers|revokeTokens|disableUser|help] -tenantURL tenantURL -userFile filename -userAttribute attributename
Usage of userManagement:
        command is one of [ auth, listTokens, listUsers, revokeTokens, disableUser, help ]
        (default is 'help')
  -help
        Display the full help text
  -loglevel integer
        Logging Level (default 0)
        0=report success/failure, status codes, response times  (default)
        1=report include response body
        2=report include request body
        3=report full trace (for debugging)
  -tenantURL tenantURL
        URL used to contact tenant: client:secret@tenant.domain
  -userFile filename
        Optional file containing a list of users
  -userAttribute attributename
        The attribute referred to by the list of users (default userid)

auth		Authenticate to the tenant using the specified client and secret
listTokens	List tokens for each user in the userFile
listUsers	Lookup all users in the tenant and list any that have never logged in
revokeTokens	Revoke tokens for each user in the userFile
disableUser	Disable each user in the userFile
help		Display the full help text

```

The userManagement program accepts 6 commands:
- auth - Authenticate to the tenant using the specified client and secret
- listTokens - List tokens for each user in the userFile
- listUsers - Lookup all users in the tenant and list any that have never logged in
- revokeTokens - Revoke tokens for each user in the userFile
- disableUser - Disable each user in the userFile
- help - Display the full help text

The userFile should contain a list of users, one per line, identified by username, email or any other searchable attribute,
that the action will be perfomed on. The userAttribute parameter tells userManagement what attribute to use when searching. 

The userManagement program will iterate through the list of users, looking up each user and applying the specified action. 
Disabling the user is done by setting their password to an invalid hash that cannot be matched. 

Setting loglevel can be useful for better understanding what API calls are made, and for debugging.

### Building the example

The bin directory contains statically linked binaries for [Linux](bin/linux/userManagement), [Mac](bin/darwin/userManagement) and 
[Windows](bin/windows/userManagement) 

These don't require any runtime and should just run on the corresponding OS.

If go is installed you can build all three binaries on Linux using the make.sh script.  
Mac and Windows developers should be able to create a similar script.  
Note that you will need the [go install from golang.org](https://golang.org/doc/install) in order to be sure of creating static 
binaries.  The gccgo package that RedHat provides creates dynamically linked binaries that require a go runtime to be installed 
before they will run.

### Descriptions of the example files

#### [main.go](main.go)

This contains the main()function, which first calls getArguments() to parse the command line arguments, and do some sanity 
checking. Then it calls getUsers() to read the userFile and build a list of all the values found, one per line.  It then calls 
doAuth() to authenticate with the client id, secret and tenant passed in the tenantURL command line argument.  If the command was 
one of the actions listTokens, revokeTokens, or disableUser, and a userAttribute was specified, the lookupUser() function is 
called for each user in the userFile to find the corresponding user id. Then listTokens(), revokeTokens(), or disableUser() is 
called for each of the users that was returned from lookupUser.

#### [doAuth.go](doAuth.go)

This contains the doAuth() function, which calls the token API to get an access token.  This is saved by main() into the configInfo
structure and all the other functions pass it as a Bearer token in an Authorization header on their API calls.
This looks like
```text
req.Header.Add("Authorization", "Bearer "+configInfo.accessToken)
```
This file also contains the checkAuth() function which calls doAuth() if the token has expired.  All of the other functions call
checkAuth() before calling their API.

#### [lookupUser.go](lookupUser.go)

This contains the lookupUser() function, which calls the Users API to find a user matching each line from the userFile.  The
userAttribute parameter determines which attribute is passed on the Users call with an equality search. It is intended that
each line in the userFile matches a single user in the tenant, so only the first result is looked at.  If there is a result
returned, the user id is returned to the caller.

#### [listTokens.go](listTokens.go)

This contains the listTokens() function, which calls the grants API to find all the tokens corresponding to the userid that was
returned by lookupUser.

#### [revokeTokens.go](revokeTokens.go)

This contains the revokeTokens() function, which calls the grants API to delete each token that was returned by listTokens().

#### [disableUser.go](disableUser.go)

This contains the disableUser() function, which calls the Users API to modify the user's password to an invalid hash.  This is done
with the PATCH operation which takes a json structure describing the exact attribute to modify, the operation (add/delete/replace)
and the value.

#### [listUsers.go](listUsers.go)

This contains the listUsers() function, which calls the Users API to get a list of users in the tenant, then reports on any users
that have not logged in.  It does this by repeatedly calling getUserList() with the next userId to start with, and the list of
attributes to return.  The Users API will return up to 2500 users per call.  For each set of users returned, the filterUserList()
function is called to look for any users without the lastLogin attribute, and print out the userid, email and create time.  This
function can be modified to do any other desired processing of the user information.
