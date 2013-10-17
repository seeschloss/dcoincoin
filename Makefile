DC=ldc2

all: dcoincoin-cli

dcoincoin-cli:
ifeq ($(DC),gdc)
	gdc -lcurl -lpanel -lncursesw -Isrc -obin/dcoincoin-cli src/dcc/dcoincoin.d src/dcc/conf.d src/dcc/uput.d src/dcc/tribune.d src/ini/dini.d
else
	mkdir -p build
	$(DC) -L-lcurl -L-lpanel -L-lncursesw -odbuild -Isrc -ofbin/dcoincoin-cli src/dcc/dcoincoin.d src/dcc/conf.d src/dcc/uput.d src/dcc/tribune.d src/ini/dini.d
endif
