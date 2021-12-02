GOOS=linux GOARCH=amd64 go build  -o bin/linux/csvHasher .
GOOS=darwin GOARCH=amd64 go build -o bin/darwin/csvHasher .
GOOS=windows GOARCH=amd64 go build -o bin/windows/csvHasher.exe .
