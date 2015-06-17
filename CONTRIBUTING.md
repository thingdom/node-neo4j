## Development

    git clone git@github.com:thingdom/node-neo4j.git
    cd node-neo4j
    npm install && npm run clean

You'll need a local installation of Neo4j ([links](http://neo4j.org/download)),
and it should be running on the default port of 7474 (`neo4j start`).

To run the tests:

    npm test

This library is written in [CoffeeScript][], using [Streamline.js][] syntax.
The tests automatically compile the code on-the-fly, but you can also generate
compiled `.js` files from the source `._coffee` files manually:

    npm run build

This is in fact what's run each time this library is published to npm.
But please don't check the generated `.js` files in; to remove:

    npm run clean

When compiled `.js` files exist, changes to the source `._coffee` files will
*not* be picked up automatically; you'll need to rebuild.

If you `npm link` this module into another app (like [node-neo4j-template][])
and you want the code compiled on-the-fly during development, you can create
an `index.js` file under `lib/` with the following:

```js
require('coffee-script/register');
require('streamline/register');
module.exports = require('./index._coffee');
```

But don't check this in! That would cause all clients to compile the code
on-the-fly every time, which isn't desirable in production.
