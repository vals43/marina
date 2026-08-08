SOURCES = my.ml prop.ml sat_ifexpr.ml marina.ml main.ml
EXEC = marina
SERVER_SOURCES = my.ml prop.ml sat_ifexpr.ml marina.ml server.ml
SERVER_EXEC = server

CAMLC = ocamlc
CAMLDEP = ocamldep
CAMLDOC = ocamldoc

LIBS = str.cma
SERVER_LIBS = str.cma unix.cma
CUSTOM = -custom

all: depend $(EXEC)

OBJS = $(SOURCES:.ml=.cmo)

$(EXEC): $(OBJS)
	$(CAMLC) $(CUSTOM) -o $(EXEC) $(LIBS) $(OBJS)

server: $(SERVER_SOURCES:.ml=.cmo)
	$(CAMLC) $(CUSTOM) -o $(SERVER_EXEC) $(SERVER_LIBS) $(SERVER_SOURCES:.ml=.cmo)

.SUFFIXES: .ml .mli .cmo .cmi

%.cmo: %.ml
	$(CAMLC) -c $<

%.cmi: %.mli
	$(CAMLC) -c $<

doc: all
	mkdir -p doc
	rm -rf doc/*
	$(CAMLDOC) -d doc/ -html *.mli

clean:
	rm -f *.cm[io] *~ .*~ #*#
	rm -f $(EXEC) $(SERVER_EXEC)
	rm -rf doc
	rm .depend

test:
	ocamlfind ocamlc -package ounit2 -linkpkg -o test str.cma my.ml prop.ml sat_ifexpr.ml marina.ml test.ml
	./test

.depend: $(SOURCES)
	$(CAMLDEP) *.mli *.ml > .depend

depend: $(SOURCES)
	$(CAMLDEP) *.mli *.ml > .depend

include .depend
