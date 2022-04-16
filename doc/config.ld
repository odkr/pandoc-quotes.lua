project = 'pandoc-quotes.lua'
description = ''
full_description = [[

See its [GitHub repository](https://github.com/odkr/pandoc-quotes.lua/) for details.]]

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
