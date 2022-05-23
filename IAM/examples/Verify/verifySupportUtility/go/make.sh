GOOS=linux GOARCH=amd64 go build  -o bin/linux/verifySupportUtility .
GOOS=darwin GOARCH=amd64 go build -o bin/darwin/verifySupportUtility .
GOOS=windows GOARCH=amd64 go build -o bin/windows/verifySupportUtility.exe .
