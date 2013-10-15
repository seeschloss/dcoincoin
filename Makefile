DC=rdmd
DCFLAGS=--build-only -L-lpanel -L-lncursesw

all: dcoincoin-cli

dcoincoin-cli:
	$(DC) $(DCFLAGS) -Isrc -ofbin/dcoincoin-cli src/dcc/dcoincoin.d
