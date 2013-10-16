DC=dmd
DCFLAGS=-L-lcurl -L-lpanel -L-lncursesw

all: dcoincoin-cli

dcoincoin-cli:
	mkdir -p build
	$(DC) $(DCFLAGS) -odbuild -Isrc -ofbin/dcoincoin-cli src/dcc/dcoincoin.d src/dcc/conf.d src/dcc/uput.d src/dcc/tribune.d src/ini/dini.d
