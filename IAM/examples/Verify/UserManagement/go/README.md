# IBM Security Performance

## Verify - Identity and Access Management

### Verify examples - User Management

This directory contains Golang example code for bulk management of users.  The userManagement program performs
actions on a set of users, including listing tokens, revoking tokens and disabling the user by setting the password
to an unmatchable hash.  These are done by calling the Verify APIs.  

* [Documentation](#documentation)
** [Create an API client](#create-an-api-client)
** [Get an oauth token](#get-an-oauth-token)
** [Lookup users](#lookup-users)
** [Lookup grants](#lookup-grant)
** [Delete grant](#delete-grant)
** [Modify password](#modify-password)
* [Usage of the example](#usage-of-the-example)
* [Building the example](#building-the-example)

#### Documentation

The [IBM Security Verify Documentation Hub](https://docs.verify.ibm.com/verify/) provides
comprehensive guides and documentation to help you start working with IBM Security Verify as quickly as possible, 
as well as support if you get stuck.  

Of particular interest for these examples are the [Getting Started](https://docs.verify.ibm.com/verify/docs/guides)
guides and the [API Documentation](https://docs.verify.ibm.com/verify/page/api-documentation) since the example code
is calling a series of APIs.  
￼
##### Create an API client

The Getting Started page for [Create an API client](https://docs.verify.ibm.com/verify/docs/create-api-client) describes
how to create an API client with the appropriate accesses.  The accesses that you need to call each API is described in
the documentation for that API.  

##### Get an oauth token

The first thing any program will need to do before calling the APIs is to get an oauth token, which it will pass on
each subsequent API call.  The Getting Started page for [Client Credentials](https://docs.verify.ibm.com/verify/docs/get-an-access-token)
describes getting the oauth token for making API calls, using the client ID and secret that were generated when you
created the API client.  
￼
The API documentation [Get the access token](https://docs.verify.ibm.com/verify/reference/handletoken) page is the 
API reference for that call.  Each page describes what the API does, what each of the input parameters and form data fields
is, along with the types and allowable values.  On the right-hand side of the page is example code in 16 languages 
plus curl command line examples, along with examples of the possible successful and unsuccessful responses.  

As you read through the example code functions, you can compare them to the Go example code.
The oauth token is retrieved in [doAuth.go](doAuth.go)  
￼
##### Lookup users

The API documentation [Get Users](https://docs.verify.ibm.com/verify/reference/getusers) page describes how to search
for specific users.  The userManagement example uses this to lookup up the information provided, such as username or
email, to get the user id for each user to pass in subsequent calls.

The user lookup code is in [lookupUser.go](lookupUser.go)

##### Lookup grants

The API documentation [Read Grants](https://docs.verify.ibm.com/verify/reference/readgrants_0) page describes how to
retrieve a list of grants associated with a specific userid.

The grant lookup code is in [listTokens.go](listTokens.go)

##### Delete grant

The API documentation [Delete Grant](https://docs.verify.ibm.com/verify/reference/deletegrant) page describes how to
delete a specific grant.

The grant deletion code is in [revokeTokens.go](revokeTokens.go)

##### Modify password

The API documentation [Patch User](https://docs.verify.ibm.com/verify/reference/patchuser) page describes how to
modify attributes for a specific user.  
￼
The user modify code is in [disableUser.go](disableUser.go)



#### Usage of the example
```text
Usage: userManagement [auth|listTokens|revokeTokens|disableUser] -tenantURL tenantURL -userFile filename
Usage of userManagement:
        command is one of [ auth, listTokens, revokeTokens, disableUser, help ]
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
revokeTokens	Revoke tokens for each user in the userFile
disableUser	Revoke tokens and disable each user in the userFile
help		Display the full help text

```

The userManagement program accepts 5 commands:
- auth		Authenticate to the tenant using the specified client and secret
- listTokens	List tokens for each user in the userFile
- revokeTokens	Revoke tokens for each user in the userFile
- disableUser	Revoke tokens and disable each user in the userFile
- help		Display the full help text

The userFile should contain a list of users, one per line, identified by username, email or any other searchable attribute.
The userAttribute parameter tells userManagement what attribute to use when searching.
The userManagement program will iterate through the list of users, looking up each user and applying the specified action.
Disabling the user is done by setting their password to an invalid hash that cannot be matched.

#### Building the example

Binaries have been built for [Linux](bin/linux/userManagement), [Mac](bin/darwin/userManagement) and 
[Windows](bin/windows/userManagement) which don't require any runtime and should just run.

If go is installed you can build the examples on Linux using the make.sh script.  Mac and Windows developers should
be able to create a similar script.
