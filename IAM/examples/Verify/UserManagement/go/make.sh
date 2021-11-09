GOOS=linux GOARCH=amd64 go build  -o bin/linux/userManagement .
GOOS=darwin GOARCH=amd64 go build -o bin/darwin/userManagement .
GOOS=windows GOARCH=amd64 go build -o bin/windows/userManagement.exe .
