package main

import (
	"fmt"
	tus "github.com/eventials/go-tus"
	"os"
)

// uploadFile uploads the specified file to Verify
func uploadFile(configInfo *ConfigInfo) (err error) {

	f, err := os.Open(configInfo.uploadFile)

	if err != nil {
		return
	}

	defer f.Close()

	// create the tus client.
	client, err := tus.NewClient("https://"+configInfo.tenantHostname + configInfo.serverEndpoint + uploadPath, nil)

	if err != nil {
		return
	}

	client.Header.Set("Authorization", "Bearer "+configInfo.accessToken)
	client.Header.Set("X-Forwarded-Host", configInfo.tenantHostname)

	if configInfo.logLevel >= 1 {
		fmt.Printf("Calling %s\n", "https://"+configInfo.tenantHostname + configInfo.serverEndpoint + uploadPath)
	}

	// create an upload from a file.
	upload, err := tus.NewUploadFromFile(f)

	if err != nil {
		return
	}

	upload.Metadata["Comment"] = configInfo.uploadComment

	// create the uploader.
	uploader, err := client.CreateUpload(upload)

	if err != nil {
		return
	}

	// start the uploading process.
	err = uploader.Upload()

	return
}

