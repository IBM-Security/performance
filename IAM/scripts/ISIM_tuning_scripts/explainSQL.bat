set DATABASE=ldapdb2

db2 connect to %DATABASE%
db2 set current explain mode explain
db2 -f %1
db2 commit work
db2 connect reset
db2 terminate
db2exfmt -d %DATABASE% -g TIC -n %% -s %% -w -1 -# 0 -o %1.exfmt

