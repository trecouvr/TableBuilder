

OPA=opa
OPAOPT=--parser classic
FILES=$(shell find src -name '*.opa')
EXE=main.exe

all: $(FILES)
	$(OPA) $(OPAOPT) $^ -o main.exe

run:
	./$(EXE) --db-local db/db

new-db:
	./$(EXE) --db-local db/db --db-force-upgrade

clean-db:
	rm -rf db/*

clean:
	rm -rf *.opx *.opx.broken
	rm -f *.exe
	rm -rf doc
	rm -rf _build _tracks
	rm -f *.log
	rm -f *.apix
	rm -f src/*.api
	rm -rf *.opp
	rm -f src/*.api-txt

