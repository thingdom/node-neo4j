coffee = require 'coffee-script'
streamline = require 'streamline'

fs = require 'fs'

# TEMP HACK manually supporting streamline+coffee
if require.extensions
    require.extensions['.coffee'] = (module, filename) ->
        content = coffee.compile fs.readFileSync(filename, 'utf8'), {bare: true}
        if filename.match /_\.coffee$/
            content = streamline.transform.transform content
        module._compile content, filename

require './crud_'