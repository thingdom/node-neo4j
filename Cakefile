FS = require 'fs'
Path = require 'path'

# XXX Not possible to use Streamline syntax in Cakefiles yet, so we use sync
# functions wherever we can for now. TODO FIXME if it becomes possible! =)

# Compile all CoffeeScript + Streamline source into regular JavaScript.
#
# Achieve this by compiling the CoffeeScript to JavaScript first, still in
# Streamline syntax, then compiling that to regular JavaScript.
#
# Note that neither calling the Streamline compiler directly nor using
# Streamline's compile() function will work here, because:
#
# - Our source files have basenames *without* an underscore, e.g. foo.coffee,
#   which would be equivalent to foo.coffee;
#
# - We use Streamline 0.2's in-file directive -- `return if not require(…)… --
#   which Streamline only checks for if no underscore basename is present;
#
# - And in the case that it sees it, it won't write the generated JavaScript
#   to a file alongside the source -- it's meant for on-the-fly compilation.
#
# But the internal (thankfully, exposed) loadFile() function, which handles
# all this, *does* return the transformed source. XXX So that's what we use.
# Update: transformModule() actually; it's the sync equivalent of loadFile().
#
# Minor note: we compile CoffeeScript with the bare option since Streamline
# wraps the generated JS in its own closure. Not a big deal either way.

task 'build', ->

    Coffee = require 'coffee-script'
    Streamline = require 'streamline/lib/compiler/compile'

    # iterate over all source .coffee files and generate the compiled .js:
    for filename in FS.readdirSync 'lib'

        path = Path.join 'lib', filename
        ext = Path.extname path

        continue if ext isnt '.coffee'

        source = FS.readFileSync path, 'utf8'
        compiled = Coffee.compile source, {bare: true}
        compiled = Streamline.transformModule compiled, path
        FS.writeFileSync "#{path.replace ext, '.js'}", compiled

task 'clean', ->

    # remove all .js files that have a matching .coffee sibling:
    for filename in FS.readdirSync 'lib'

        path = Path.join 'lib', filename
        ext = Path.extname path

        continue if ext isnt '.js'
        continue if not Path.existsSync "#{path.replace ext, '.coffee'}"

        FS.unlinkSync path
