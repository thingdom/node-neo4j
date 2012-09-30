# Node-Neo4j

This is a client library for accessing [Neo4j][], a graph database, from
[Node.js][]. It uses Neo4j's [REST API][neo4j-rest-api].

This library supports and has been tested against Neo4j 1.4, 1.5 and 1.6. We
need to formally test 1.7 and 1.8, but it's being used in the wild against
those versions of Neo4j seemingly without any issues.


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
corresponding HTTP requests and responses finish.

Here's a simple example:

```js
var node = db.createNode({hello: 'world'});     // instantaneous, but...
node.save(function (err, node) {    // ...this is what actually persists.
    if (err) {
        console.err('Error saving new node to database:', err);
    } else {
        console.log('Node saved to database with id:', node.id);
    }
});
```

Because async flow in Node.js can be significantly tricky to handle, we
strongly recommend using a flow control tool or library to help.
Our personal favorite is [Streamline.js][], but other popular choices are
[async](https://github.com/caolan/async),
[Step](https://github.com/creationix/step),
[Seq](https://github.com/substack/node-seq), [TameJS](http://tamejs.org/) and
[IcedCoffeeScript](http://maxtaco.github.com/coffee-script/).

Once you've gotten the basics down, skim through the full
**[API documentation][api-docs]** to see what this library can do, and take a
look at [@aseemk][aseemk]'s [node-neo4j-template][] app for a complete usage
example. (The `models/User.js` file in particular is the one that interacts
with this library.)

Please note that **breaking changes to this library are *very* likely** in the
near future as we consider an API overhaul, but the version number will always
respect [semantic versioning][semver]. So if you specify this library as a
dependency in your package.json, ***please* specify something like `0.2.x` or
`~0.2.6`, *not* `>=0.2.6`**. Thanks. =)


## Development

    git clone git@github.com:thingdom/node-neo4j.git
    cd node-neo4j
    npm install && npm run clean

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

**Important:** The tests are written assuming Neo4j >=1.7 and will now fail on
prior Neo4j versions, but the library supports prior Neo4j versions just fine.

This library is written in [CoffeeScript][], using [Streamline.js][] syntax.
The tests automatically compile the code on-the-fly, but you can also generate
compiled `.js` files from the source `._coffee` files manually:

    npm run build

This is in fact what's run when this library is installed by npm. But please
don't check the generated `.js` files in; to remove:

    npm run clean

When compiled `.js` files exist, changes to the source `._coffee` files will
*not* be picked up automatically; you'll need to rebuild.

If you `npm link` this module into another app (like [node-neo4j-template][])
and you want the code compiled on-the-fly during development, you can create
an `index.js` file under `lib/` with the following:

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

[api-docs]: http://coffeedoc.info/github/thingdom/node-neo4j/master/
[aseemk]: https://github.com/aseemk
[node-neo4j-template]: https://github.com/aseemk/node-neo4j-template
[semver]: http://semver.org/

[neo4j-getting-started]: http://wiki.neo4j.org/content/Getting_Started_With_Neo4j_Server
[coffeescript]: http://coffeescript.org/
[streamline.js]: https://github.com/Sage/streamlinejs

[issue-tracker]: https://github.com/thingdom/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html
