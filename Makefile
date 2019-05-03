test: test-simple test-lookup test-lookup-harder test-lookup-hardest

test-simple:
	rm -f test/simple-is.html
	pandoc --lua-filter pandoc-quotes.lua test/simple.md \
		-o test/simple-is.html
	cmp test/simple-is.html test/simple-should.html

test-lookup:
	rm -f test/lookup-is.html
	pandoc --lua-filter pandoc-quotes.lua test/lookup.md \
		-o test/lookup-is.html
	cmp test/lookup-is.html test/lookup-should.html

test-lookup-harder:
	rm -f test/lookup-harder-is.html
	pandoc --lua-filter pandoc-quotes.lua test/lookup-harder.md \
		-o test/lookup-harder-is.html
	cmp test/lookup-harder-is.html test/lookup-harder-should.html

test-lookup-hardest:
	rm -f test/lookup-hardest-is.html
	pandoc --lua-filter pandoc-quotes.lua test/lookup-hardest.md \
		-o test/lookup-hardest-is.html
	cmp test/lookup-hardest-is.html test/lookup-hardest-should.html


.PHONY: test test-simple test-lookup test-lookup-harder test-lookup-hardest
