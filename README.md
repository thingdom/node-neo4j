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

TODO: we should be clearing the database before/after; how to do this?
(Note: clearing the `db/data` dir is *not* safe according to Daniel)

    expresso test/index.js

Yeah, for the time being it's too bad we have to specify `index.js`. Some day...
(This is because right now, Expresso natively supports neither Streamline nor
helper files like `setup.js`. I'll request these things when I get a chance.)

You can write more tests by making new files that export test functions (one
test case per file is the limitation right now), e.g.:

    module.exports = function (beforeExit) {
        // your test case here
    };

And update `test/index.js` to include these test cases.

If you want to use Streamline syntax in your test cases (very convenient for
asynchronous calls), name the file with the postfix `_.js` but keep an empty
`.js` around, and add a `_` arg after `beforeExit`. You'll need to check in the
`.js` file for now; I'm working with the Streamline author on fixing this.


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
