# Node-Neo4j

This driver lets you access [Neo4j][], a graph database, from [Node.js][].
It uses Neo4j's [REST API][neo4j-rest-api].

This library supports and has been tested against Neo4j 1.4, 1.5 and 1.6.


## Installation

    npm install neo4j


## Usage

To start, create a new instance of the `GraphDatabase` class pointing to your
Neo4j instance:

```js
var neo4j = require('neo4j');
var db = new neo4j.GraphDatabase('http://localhost:7474');
```

Node.js is asynchronous, which means this library is too: most functions take
callbacks and return immediately, with the callbacks being invoked when the
HTTP request-response finishes.

Here's a simple callback for exploring and learning this library:

```js
function callback(err, result) {
    if (err) {
        console.error(err);
    } else {
        console.log(result);    // if an object, inspects the object
    }
}
```

Creating a new node:

```js
var node = db.createNode({hello: 'world'});     // instantaneous, but...
node.save(callback);    // ...this is what actually persists it in the db.
```

Fetching an existing node or relationship, by ID:

```js
db.getNodeById(1, callback);
db.getRelationshipById(1, callback);
```

And so on.

For a complete example of usage, take a look at [@aseemk][aseemk]'s
[node-neo4j-template][] app. The `models/User.js` file in particular is the
one that interacts with this library.

**A note on package.json dependencies:**

Future breaking changes to this library are likely! But the version numbers
will respect [semantic versioning][semver]. So **please specify something like
`0.2.x` or `~0.2.6`, *not* `>=0.2.6`**. Thank you.


## Development

    git clone git@github.com:thingdom/node-neo4j.git
    cd node-neo4j
    npm link

You'll also need a local Neo4j database instance for the tests:

    curl http://dist.neo4j.org/neo4j-community-1.6-unix.tar.gz --O neo4j-community-1.6-unix.tar.gz
    tar -zxvf neo4j-community-1.6-unix.tar.gz
    mv neo4j-community-1.6 db

If you're new to Neo4j, read the [Getting Started][neo4j-getting-started] page.
Start the server:

    db/bin/neo4j start

Stop the server:

    db/bin/neo4j stop

To run the tests:

    npm test

**Important:** The tests are written assuming Neo4j >=1.5 and will now fail on
Neo4j 1.4, but the library supports Neo4j 1.4 fine.

This library is written in [CoffeeScript][], using [Streamline.js][] syntax.
The tests automatically compile the code on-the-fly, but you can also generate
compiled `.js` files from the source `._coffee` files manually:

    npm run build

This is in fact what's run when this library is published to npm. But please
don't check the generated `.js` files in; to remove:

    npm run clean

When compiled `.js` files exist, changes to the source `._coffee` files will
*not* be picked up automatically; you'll need to rebuild.

If you link this module into another app (like [node-neo4j-template][]) and
you want the code compiled on-the-fly during development, you can create an
`index.js` file under `lib/` with the following:

```js
require('coffee-script');
require('streamline').register();
module.exports = require('./index._coffee');
```

But don't check this in! That would cause all clients to compile the code
on-the-fly every time, which isn't desirable in production.


## License

This library is licensed under the [Apache License, Version 2.0][license].


## Reporting Issues

If you encounter any bugs or other issues, please file them in the
[issue tracker][issue-tracker].


[neo4j]: http://neo4j.org/
[node.js]: http://nodejs.org/
[neo4j-rest-api]: http://docs.neo4j.org/chunked/1.6/rest-api.html

[aseemk]: https://github.com/aseemk
[node-neo4j-template]: https://github.com/aseemk/node-neo4j-template
[semver]: http://semver.org/

[neo4j-getting-started]: http://wiki.neo4j.org/content/Getting_Started_With_Neo4j_Server
[coffeescript]: http://coffeescript.org/
[streamline.js]: https://github.com/Sage/streamlinejs

[issue-tracker]: https://github.com/thingdom/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html