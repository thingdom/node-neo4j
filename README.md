<!--
Possible badges:

[![Build Status](https://travis-ci.org/thingdom/node-neo4j.svg?branch=master)](https://travis-ci.org/thingdom/node-neo4j)

[![npm version](https://badge.fury.io/js/neo4j.svg)](http://badge.fury.io/js/neo4j)

[![NPM](https://nodei.co/npm/neo4j.png?compact=true)](https://nodei.co/npm/neo4j/)

We choose to use the first two, but we write them as HTML so that we can inline
and `float: right` them in the Node-Neo4j header. (Admittedly, yucky markup.)
-->

# Node-Neo4j <a href="https://travis-ci.org/thingdom/node-neo4j" style="float: right; margin-left: 0.25em;"><img src="https://travis-ci.org/thingdom/node-neo4j.png?branch=master"/></a> <a href="http://badge.fury.io/js/neo4j" style="float: right;"><img src="https://badge.fury.io/js/neo4j.svg" alt="npm version" height="18"></a>

This is a Node.js driver for [Neo4j](http://neo4j.com/), a graph database.

**This driver has undergone a complete rewrite for Neo4j v2.**
It now *only* supports Neo4j 2.x — but it supports it really well.
(If you're still on Neo4j 1.x, you can still use
[node-neo4j v1](https://github.com/thingdom/node-neo4j/tree/v1).)

<!-- TODO: E.g. "Take a look at the instructions below,
then read the full [API docs](./docs) for details?" -->

<!-- TODO: Mention goals of driver? E.g. comprehensive, robust.
Similarly, mention used in production by FiftyThree? -->


## Installation

```sh
npm install neo4j --save
```


## Usage

```js
var neo4j = require('neo4j');
var db = new neo4j.GraphDatabase('http://localhost:7474');

db.cypher({
    query: 'MATCH (u:User {email: {email}}) RETURN u',
    params: {
        email: 'alice@example.com',
    },
}, function (err, results) {
    if (err) throw err;
    var result = results[0];
    if (!result) {
        console.log('No user found.');
    } else {
        var user = result['u'];
        console.log(JSON.stringify(user, null, 4));
    }
});
```

Yields e.g.:

```json
{
    "_id": 12345678,
    "labels": [
        "User",
        "Admin"
    ],
    "properties": {
        "name": "Alice Smith",
        "email": "alice@example.com",
        "emailVerified": true,
        "passwordHash": "..."
    }
}
```

<!-- TODO: Update the below. -->

Node.js is asynchronous, which means this library is too: most functions take
callbacks and return immediately, with the callbacks being invoked when the
corresponding HTTP requests and responses finish.

Because async flow in Node.js can be quite tricky to handle, we
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

This library is officially stable at "v1", but "v2" will almost certainly have
breaking changes to support only Neo4j 2.0 and generally improve the API
([roadmap][]). You can be sheltered from these changes if you simply specify
your package.json dependency as e.g. `1.x` or `^1.0` instead of `*`.

[Roadmap]: https://github.com/thingdom/node-neo4j/wiki/Roadmap


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


## Changes

See the [Changelog][changelog] for the full history of changes and releases.


## License

This library is licensed under the [Apache License, Version 2.0][license].


## Feedback

If you encounter any bugs or other issues, please file them in the
[issue tracker][issue-tracker].

We also now have a [Google Group][google-group]!
Post questions and participate in general discussions there.


[neo4j]: http://neo4j.org/
[node.js]: http://nodejs.org/
[neo4j-rest-api]: http://docs.neo4j.org/chunked/stable/rest-api.html

[api-docs]: http://coffeedoc.info/github/thingdom/node-neo4j/master/
[aseemk]: https://github.com/aseemk
[node-neo4j-template]: https://github.com/aseemk/node-neo4j-template
[semver]: http://semver.org/

[neo4j-getting-started]: http://wiki.neo4j.org/content/Getting_Started_With_Neo4j_Server
[coffeescript]: http://coffeescript.org/
[streamline.js]: https://github.com/Sage/streamlinejs

[changelog]: CHANGELOG.md
[issue-tracker]: https://github.com/thingdom/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html
[google-group]: https://groups.google.com/group/node-neo4j
