# Makefile to build Secure Bash for macOS

BOOK_DIR := ebook
OUTPUT_DIR := output
METADATA := metadata.yaml
COVER := $(BOOK_DIR)/assets/images/cover.png

CHAPTERS := \
    $(BOOK_DIR)/about.md \
    $(wildcard $(BOOK_DIR)/part1_bash_fundamentals/*.md) \
    $(wildcard $(BOOK_DIR)/part2_advanced_security/*.md) \
    $(wildcard $(BOOK_DIR)/part3_real_world_projects/*.md) \
    $(wildcard $(BOOK_DIR)/appendices/*.md)

.PHONY: all pdf epub html clean

all: pdf epub html

pdf:
	mkdir -p $(OUTPUT_DIR)
	# Copy cover image to root for LaTeX to find it more easily
	cp $(COVER) cover.png
	pandoc $(CHAPTERS) --metadata-file=$(METADATA) -V geometry:margin=1in -V titlepage=true -V titlepage-background=cover.png -o $(OUTPUT_DIR)/Secure-Bash-for-macOS.pdf
	rm -f cover.png

epub:
	mkdir -p $(OUTPUT_DIR)
	pandoc $(CHAPTERS) --metadata-file=$(METADATA) --cover-image=$(COVER) -o $(OUTPUT_DIR)/Secure-Bash-for-macOS.epub

html:
	mkdir -p $(OUTPUT_DIR)
	pandoc $(CHAPTERS) --metadata-file=$(METADATA) -s -o $(OUTPUT_DIR)/Secure-Bash-for-macOS.html

clean:
	rm -rf $(OUTPUT_DIR)/*
