# Neo4j driver (REST API client) for Node.js

This driver lets you access [Neo4j][neo4j], a graph database, from Node.js.
It uses Neo4j's [REST API][neo4j-rest-api].

This library supports and has been tested against Neo4j 1.4, 1.5 and 1.6.


## Installation

    npm install neo4j


## Usage

To start, create a new instance of the `GraphDatabase` class pointing to your
Neo4j instance:

    var neo4j = require('neo4j');
    var db = new neo4j.GraphDatabase('http://localhost:7474');

Node.js is asynchronous, which means this library is too: most functions take
callbacks and return immediately, with the callbacks being invoked when the
HTTP request-response finishes.

Here's a simple callback for exploring and learning this library:

    function callback(err, result) {
        if (err) {
            console.error(err);
        } else {
            console.log(result);    // if an object, inspects the object
        }
    }

Creating a new node:

    var node = db.createNode({hello: 'world'});     // instantaneous, but...
    node.save(callback);    // ...this is what actually persists it in the db.

Fetching an existing node or relationship, by ID:

    db.getNodeById(1, callback);
    db.getRelationshipById(1, callback);

And so on.


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


## License

This library is licensed under the [Apache License, Version 2.0][license].


## Reporting Issues

If you encounter any bugs or other issues, please file them in the
[issue tracker][issue-tracker].


[neo4j]: http://neo4j.org/
[neo4j-rest-api]: http://docs.neo4j.org/chunked/1.6/rest-api.html
[neo4j-getting-started]: http://docs.neo4j.org/chunked/stable/
[issue-tracker]: https://github.com/thingdom/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html
