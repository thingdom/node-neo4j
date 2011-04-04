Neo4j REST API Client for Node.js
=================================

This client library let's you access the [Neo4j REST API][neo-rest-api] through
a simple JavaScript API.


Installation
------------

    npm install https://github.com/gasi/node-neo4j/tarball/0.0.3


Development
------------

    git clone git@github.com:gasi/node-neo4j.git neo4j
    cd neo4j
    npm link

You'll also need a local neo4j database instance for the tests:

    curl http://dist.neo4j.org/neo4j-1.3.M05-unix.tar.gz --O neo4j-1.3.M05-unix.tar.gz
    tar -zxvf neo4j-1.3.M05-unix.tar.gz
    mv neo4j-1.3.M05 db

If you're new to Neo4j, read the [Getting Started][neo4j-getting-started] page.
To start/stop the server:

    db/bin/neo4j start
    db/bin/neo4j stop


Usage
-----

    var neo4j = require('neo4j');
    var client = new neo4j.Client('localhost', 7474, /*autoMarshal*/ true);

    function print(err, res) {
        console.log(err ? err : res);
    }

    client.createNode({'hello': 'world'}, print);


Test
----

The tests assume a database instance is running:

    db/bin/neo4j start

TODO we should be clearing the database before/after; how to do this? is there a command? is clearing the db/data dir safe?

    node test


License
-------

This library is licensed under the [Apache License, Version 2.0][license].


Reporting Issues
----------------

If you encounter any bugs or other issues, please file them in the
[issue tracker][issue-tracker].


[neo-rest-api]: http://components.neo4j.org/neo4j-server/snapshot/rest.html
[neo4j-getting-started]: http://wiki.neo4j.org/content/Getting_Started_With_Neo4j_Server
[issue-tracker]: https://github.com/gasi/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html