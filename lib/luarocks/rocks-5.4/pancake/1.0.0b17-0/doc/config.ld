project = 'Pancake'
description = 'Toolkit to write Lua filters for Pandoc.'
full_description = [[Pancake aides with

* maintaining compatibility accross different versions of Pandoc
* working with complex data structures
* error handling
* string interpolation
* object-oriented programming
* file I/O and filesystem interaction
* metadata parsing (i.e., configuration)

See its [GitHub repository](https://github.com/odkr/pancake/) for details.]]

readme = 'README.md'
format = 'discount'
dir = 'doc'

backtick_references = false

new_type('object', 'Prototypes', false)

custom_tags = {
    {'caveats', title = 'Caveats'},
    {'proto', title = 'Prototype'},
    {'require', title = 'Requires'},
    {'side', title = 'Side-effects'},
    {'tip', title = 'Tip'}
}
