mds  := $(shell find mds/ -type f)
htmls := $(patsubst mds/%.md, posts/%.html, $(mds))

flags := -s -f markdown+fenced_code_blocks --to=html5\
	 --highlight-style=style.theme --css=../../../style.css\
	 --syntax-definition lang/dafny.xml\
	 --syntax-definition lang/racket.xml\
	 --template default.html5

posts/%.html:
	mkdir -p $(dir $@)
	pandoc $(flags) $(patsubst posts/%.html, mds/%.md, $@) -o $@ 

index:
	pandoc -s -f markdown --to=html5 --css=style.css index.md -o index.html

posts: $(htmls)

.PHONY: clean

clean:
	rm -rf posts/ index.html
