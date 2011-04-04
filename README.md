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

Usage
-----

    var neo4j = require('neo4j');
    var client = new neo4j.Client('localhost', 7474, true /* autoMarshal */);
    var print = function (err, res) {
        console.log(err ? err : res);
    };

    client.createNode({'hello': 'world'}, print);


Test
----

    node test


License
-------

This library is licensed under the [Apache License, Version 2.0][license].

Reporting Issues
----------------

If you encounter any bugs or other issues, please file them in the
[issue tracker][issue-tracker].

[neo-rest-api]: http://components.neo4j.org/neo4j-server/snapshot/rest.html
[issue-tracker]: https://github.com/gasi/node-neo4j/issues
[license]: http://www.apache.org/licenses/LICENSE-2.0.html