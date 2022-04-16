# DIRECTORIES
# ===========

BASE_DIR	:= test
DATA_DIR	:= $(BASE_DIR)/docs
NORM_DIR	:= $(BASE_DIR)/norms
TEMP_DIR	:= $(BASE_DIR)/tmp


# PROGRAMMES
# ==========

MKDIR		?= mkdir
PANDOC		?= pandoc
RM		?= rm
SHELL		?= sh


# FILES
# =====

FILTER		?= ./pandoc-quotes.lua


# DOCUMENTS
# =========

DOCS	= $(wildcard $(DATA_DIR)/*.md)
TESTS	= $(notdir $(DOCS:.md=))

all: lint test

test: $(TESTS)

$(TESTS): tempdir
	$(PANDOC) -f markdown -t plain -L $(FILTER) \
		-o $(TEMP_DIR)/$@.txt $(DATA_DIR)/$@.md
	@diff $(TEMP_DIR)/$@.txt $(NORM_DIR)/$@.txt

lint:
	@luacheck $(FILTER) || [ $$? -eq 127 ]

tempdir:
	@$(RM) -rf $(TEMP_DIR)
	@$(MKDIR) -p $(TEMP_DIR)

%.1: %.rst
	$(PANDOC) -f rst -t man -s --output=$@ \
	    --metadata=title=$(notdir $*) \
	    --metadata=section=1 \
	    --metadata=date="$$(date '+%B %d, %Y')" \
	    $*.rst

%.1.gz: %.1
	gzip --force $<

%.lua: man/man1/%.lua.rst
	$(SHELL) scripts/header-add-man -f $@
	
doc/index.html: $(FILTER) README.md doc/config.ld
	ldoc -c doc/config.ld .

man: man/man1/$(FILTER).lua.1.gz

docs: man/man1/$(FILTER).lua.1.gz $(FILTER) doc/index.html

.PHONY: all docs lint man test tempdir $(TESTS)
