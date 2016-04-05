# Node-Neo4j

[![npm version](https://badge.fury.io/js/neo4j.svg)](http://badge.fury.io/js/neo4j) [![Build Status](https://travis-ci.org/thingdom/node-neo4j.svg?branch=master)](https://travis-ci.org/thingdom/node-neo4j)

[Node.js](http://nodejs.org/) driver for [Neo4j](http://neo4j.com/), a graph database.

This driver aims to be the most **robust**, **comprehensive**, and **battle-tested** driver available. It's run in production by [FiftyThree](https://www.fiftythree.com/) to power the popular iOS app [Paper](https://www.fiftythree.com/paper).

_Note: if you're still on **Neo4j 1.x**, you'll need to use **[node-neo4j v1](https://github.com/thingdom/node-neo4j/tree/v1)**._

_Note: **node-neo4j v2** is a ground-up rewrite with an entirely new API. If you're currently using **node-neo4j v1**, here's the **[migration guide](./CHANGELOG.md#version-200)**._


## Features

- [**Cypher queries**](#cypher), parameters, [batching](#batching), and [**transactions**](#transactions)
- Arbitrary [**HTTP requests**](#http-plugins), for custom [Neo4j plugins](#http-plugins)
- [**Custom headers**](#headers), for [**high availability**](#high-availability), application tracing, query logging, and more
- [**Precise errors**](#errors), for robust error handling from the start
- Configurable [**connection pooling**](#tuning), for performance tuning & monitoring
- Thorough test coverage with [**>100 tests**](./test-new)
- [**Continuously integrated**](https://travis-ci.org/thingdom/node-neo4j) against [multiple versions](./.travis.yml) of Node.js and Neo4j


## Installation

```sh
npm install neo4j --save
```


## Example

```js
var neo4j = require('neo4j');
var db = new neo4j.GraphDatabase('http://username:password@localhost:7474');

db.cypher({
    query: 'MATCH (user:User {email: {email}}) RETURN user',
    params: {
        email: 'alice@example.com',
    },
}, callback);

function callback(err, results) {
    if (err) throw err;
    var result = results[0];
    if (!result) {
        console.log('No user found.');
    } else {
        var user = result['user'];
        console.log(user);
    }
};
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

See **[node-neo4j-template](https://github.com/aseemk/node-neo4j-template)** for a more thorough example.

<!-- TODO: Also link to movies example. -->


## Basics

Connect to a running Neo4j instance by instantiating the **`GraphDatabase`** class:

```js
var neo4j = require('neo4j');

// Shorthand:
var db = new neo4j.GraphDatabase('http://username:password@localhost:7474');

// Full options:
var db = new neo4j.GraphDatabase({
    url: 'http://localhost:7474',
    auth: {username: 'username', password: 'password'},
    // ...
});
```

Options:

- **`url` (required)**: the base URL to the Neo4j instance, e.g. `'http://localhost:7474'`. This can include auth credentials (e.g. `'http://username:password@localhost:7474'`), but doesn't have to.

- **`auth`**: optional auth credentials; either a `'username:password'` string, or a `{username, password}` object. If present, this takes precedence over any credentials in the `url`.

- **`headers`**: optional custom [HTTP headers](#headers) to send with every request. These can be overridden per request. Node-Neo4j defaults to sending a `User-Agent` identifying itself, but this can be overridden too.

- **`proxy`**: optional URL to a proxy. If present, all requests will be routed through the proxy.

- **`agent`**: optional [`http.Agent`](http://nodejs.org/api/http.html#http_http_agent) instance, for custom [socket pooling](#tuning).

Once you have a `GraphDatabase` instance, you can make queries and more.

Most operations are **asynchronous**, which means they take a **callback**. Node-Neo4j callbacks are of the standard `(error[, results])` form.

Async control flow can get pretty tricky, so it's *highly* recommended to use a flow control library or tool, like [async](https://github.com/caolan/async) or [Streamline](https://github.com/Sage/streamlinejs).


## Cypher

To make a [Cypher query](http://neo4j.com/docs/stable/cypher-query-lang.html), simply pass the string query, any query parameters, and a callback to receive the error or results.

```js
db.cypher({
    query: 'MATCH (user:User {email: {email}}) RETURN user',
    params: {
        email: 'alice@example.com',
    },
}, callback);
```

It's extremely important to **pass `params` separately**. If you concatenate them into the `query`, you'll be vulnerable to injection attacks, and Neo4j performance will suffer as well.

Cypher queries *always* return a list of results (like SQL rows), with each result having common properties (like SQL columns). Thus, query **results** passed to the callback are *always* an **array** (even if it's empty), and each **result** in the array is *always* an **object** (even if it's empty).

```js
function callback(err, results) {
    if (err) throw err;
    var result = results[0];
    if (!result) {
        console.log('No user found.');
    } else {
        var user = result['user'];
        console.log(user);
    }
};
```

If the query results include nodes or relationships, **`Node`** and **`Relationship` instances** are returned for them. These instances encapsulate `{_id, labels, properties}` for nodes, and `{_id, type, properties, _fromId, _toId}` for relationships, but they can be used just like normal objects.

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

(The `_id` properties refer to Neo4j's internal IDs. These can be convenient for debugging, but their usage otherwise — especially externally — is discouraged.)

If you don't need to know Neo4j IDs, node labels, or relationship types, you can pass **`lean: true`** to get back *just* properties, for a potential performance gain.

```js
db.cypher({
    query: 'MATCH (user:User {email: {email}}) RETURN user',
    params: {
        email: 'alice@example.com',
    },
    lean: true,
}, callback);
```

```json
{
    "name": "Alice Smith",
    "email": "alice@example.com",
    "emailVerified": true,
    "passwordHash": "..."
}
```

Other options:

- **`headers`**: optional custom [HTTP headers](#headers) to send with this query. These will add onto the default `GraphDatabase` `headers`, but also override any that overlap.


## Batching

You can also make multiple Cypher queries within a single network request, by passing a `queries` *array* rather than a single `query` string.

Query `params` (and optionally `lean`) are then specified *per query*, so the elements in the array are `{query, params[, lean]}` objects. (Other options like `headers` remain "global" for the entire request.)

```js
db.cypher({
    queries: [{
        query: 'MATCH (user:User {email: {email}}) RETURN user',
        params: {
            email: 'alice@example.com',
        },
    }, {
        query: 'MATCH (task:WorkerTask) RETURN task',
        lean: true,
    }, {
        query: 'MATCH (task:WorkerTask) DELETE task',
    }],
    headers: {
        'X-Request-ID': '1234567890',
    },
}, callback);
```

The callback then receives an *array* of query results, one per query.

```js
function callback(err, batchResults) {
    if (err) throw err;

    var userResults = batchResults[0];
    var taskResults = batchResults[1];
    var deleteResults = batchResults[2];

    // User results:
    var userResult = userResults[0];
    if (!userResult) {
        console.log('No user found.');
    } else {
        var user = userResult['user'];
        console.log('User %s (%s) found.', user._id, user.properties.name);
    }

    // Worker task results:
    if (!taskResults.length) {
        console.log('No worker tasks to process.');
    } else {
        taskResults.forEach(function (taskResult) {
            var task = taskResult['task'];
            console.log('Processing worker task %s...', task.operation);
        });
    }

    // Delete results (shouldn’t have returned any):
    assert.equal(deleteResults.length, 0);
};
```

Importantly, batch queries execute (a) **sequentially** and (b) **transactionally**: they all succeed, or they all fail. If you don't need them to be transactional, it can often be better to parallelize separate `db.cypher` calls instead.


## Transactions

You can also batch multiple Cypher queries into a single transaction across *multiple* network requests. This can be useful when application logic needs to run in between related queries (e.g. for domain-aware cascading deletes), or Neo4j state needs to be coordinated with side effects (e.g. writes to another data store). The queries will all succeed or fail together.

To do this, begin a new transaction, make Cypher queries within that transaction, and then ultimately commit the transaction or roll it back.

```js
var tx = db.beginTransaction();

function makeFirstQuery() {
    tx.cypher({
        query: '...',
        params {...},
    }, makeSecondQuery);
}

function makeSecondQuery(err, results) {
    if (err) throw err;
    // ...some application logic...
    tx.cypher({
        query: '...',
        params: {...},
    }, finish);
}

function finish(err, results) {
    if (err) throw err;
    // ...some application logic...
    tx.commit(done);  // or tx.rollback(done);
}

function done(err) {
    if (err) throw err;
    // At this point, the transaction has been committed.
}

makeFirstQuery();
```

The transactional `cypher` method supports everything the normal [`cypher`](#cypher) method does (e.g. `lean`, `headers`, and batch `queries`). In addition, you can pass **`commit: true`** to auto-commit the transaction (and save a network request) if the query succeeds.

```js
function makeSecondQuery(err, results) {
    if (err) throw err;
    // ...some application logic...
    tx.cypher({
        query: '...',
        params: {...},
        commit: true,
    }, done);
}

function done(err) {
    if (err) throw err;
    // At this point, the transaction has been committed.
}
```

Importantly, transactions allow only one query at a time. To help preempt errors, you can inspect the **`state`** of the transaction, e.g. whether it's open for queries or not.

```js
// Initially, transactions are open:
assert.equal(tx.state, tx.STATE_OPEN);

// Making a query...
tx.cypher({
    query: '...',
    params: {...},
}, callback)

// ...will result in the transaction being pending:
assert.equal(tx.state, tx.STATE_PENDING);

// All other operations (making another query, committing, etc.)
// are rejected while the transaction is pending:
assert.throws(tx.renew.bind(tx))

function callback(err, results) {
    // When the query returns, the transaction is likely open again,
    // but it could be committed if `commit: true` was specified,
    // or it could have been rolled back automatically (by Neo4j)
    // if there was an error:
    assert.notEqual([
        tx.STATE_OPEN, tx.STATE_COMMITTED, tx.STATE_ROLLED_BACK
    ].indexOf(tx.state), -1);   // i.e. tx.state is in this array
}
```

Finally, open transactions **expire** after some period of inactivity. This period is [configurable in Neo4j](http://neo4j.com/docs/stable/server-configuration.html), but it defaults to 60 seconds today. Transactions **renew automatically** on every query, but if you need to, you can inspect transactions' expiration times and renew them manually.

```js
// Only open transactions (not already expired) can be renewed:
assert.equal(tx.state, tx.STATE_OPEN);
assert.notEqual(tx.state, tx.STATE_EXPIRED);

console.log('Before:', tx.expiresAt, '(in', tx.expiresIn, 'ms)');
tx.renew(function (err) {
    if (err) throw err;
    console.log('After:', tx.expiresAt, '(in', tx.expiresIn, 'ms)');
});
```

The full [state diagram](https://mix.fiftythree.com/aseemk/10779878) putting this all together:

[![Neo4j transaction state diagram](https://blobs-public.fiftythree.com/9LdWt0fwPjeT_o0nZ6b3o1w2qCwKs6NuNGZ4d3db86UKp2r7)](https://mix.fiftythree.com/aseemk/10779878)


## Headers

Most node-neo4j operations support passing in custom headers for the underlying HTTP requests. The `GraphDatabase` constructor also supports passing in default headers for every operation.

This can be useful to achieve a variety of features, such as:

- Logging individual queries
- Tracing application requests
- Splitting master/slave traffic (see [High Availability](#high-availability) below)

None of these things are supported out-of-the-box by Neo4j today, but all can be handled by a server (e.g. Apache or Nginx) or load balancer (e.g. HAProxy or Amazon ELB) in front.

For example, at FiftyThree, our Cypher requests look effectively like this (though we abstract and encapsulate these things with higher-level helpers):

```js
db.cypher({
    query: '...',
    params: {...},
    headers: {
        // Identify the query via a short, human-readable name.
        // This is what we log in HAProxy for every request,
        // since all Cypher calls have the same HTTP path,
        // and this is friendlier than the entire query.
        'X-Query-Name': 'User_getUnreadNotifications',

        // This tells HAProxy to send this query to the master (even
        // though it's a read), as we require strong consistency here.
        // See the High Availability section below.
        'X-Consistency': 'strong'

        // This is a concatenation of upstream services' request IDs
        // along with a randomly generated one of our own.
        // We log this header on all our servers, so we can trace
        // application requests through our entire stack.
        // TODO: Link to Heroku article on this!
        'X-Request-Ids': '123,456,789'
    },
}, callback);
```

You might also find custom headers helpful for custom [Neo4j plugins](#http-plugins).


## High Availability

Neo4j Enterprise supports running multiple instances of Neo4j in a single ["High Availability"](http://neo4j.com/docs/stable/ha.html) (HA) cluster. Neo4j's HA uses a master-slave setup, so slaves typically lag behind the master by a small delay ([tunable in Neo4j](http://neo4j.com/docs/stable/ha-configuration.html)).

There are multiple ways to interface with an HA cluster from node-neo4j, but the [recommended route](http://neo4j.com/docs/stable/ha-haproxy.html) is to place a **load balancer** in front (e.g. HAProxy or Amazon ELB). You can then point node-neo4j to the load balancer's endpoint.

```js
var db = new neo4j.GraphDatabase({
    url: 'https://username:password@lb-neo4j.example.com:1234',
});
```

You'll still want to **split traffic** between the master and the slaves (e.g. reads to slaves, writes to master), in order to distribute load and improve performance. You can achieve this through [multiple ways](http://blog.armbruster-it.de/2015/08/neo4j-and-haproxy-some-best-practices-and-tricks/):

- Create separate `GraphDatabase` instances with different `url`s to the load balancer (e.g. different host, port, or path). The load balancer can inspect the URL to route queries appropriately.

- Use the same, single `GraphDatabase` instance, but send a [custom header](#headers) to let the load balancer know where the query should go. This is what we do at FiftyThree, and what's shown in the custom header example above.

- Have the load balancer derive the target automatically, e.g. by inspecting the Cypher query. This isn't recommended. =)

With this setup, you should find node-neo4j usage with an HA cluster to be seamless.


## HTTP / Plugins

If you need functionality beyond Cypher, you can make direct HTTP requests to Neo4j. This can be useful for legacy APIs (e.g. [traversals](http://neo4j.com/docs/stable/rest-api-traverse.html)), custom plugins (e.g. [neo4j-spatial](http://neo4j-contrib.github.io/spatial/#spatial-server-plugin)), or even future APIs before node-neo4j implements them.

```js
db.http({
    method: 'GET',
    path: '/db/data/node/12345678',
    // ...
}, callback);

function callback(err, body) {
    if (err) throw err;
    console.log(body);
}
```

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

By default:

- The callback receives just the **response body** (not the status code or headers);
- Any nodes and relationships in the body are **transformed** to `Node` and `Relationship` instances (like [`cypher`](#cypher)); and
- 4xx and 5xx responses are treated as **[errors](#errors)**.

You can alternately pass **`raw: true`** for more control, in which case:

- The callback receives the ***entire* response** (with an additional `body` property);
- Nodes and relationships are ***not* transformed** into `Node` and `Relationship` instances (but the body is still parsed as JSON); and
- 4xx and 5xx responses are ***not*** treated as **errors**.

```js
db.http({
    method: 'GET',
    path: '/db/data/node/12345678',
    raw: true,
}, callback);

function callback(err, resp) {
    if (err) throw err;
    assert.equal(resp.statusCode, 200);
    assert.equal(typeof resp.headers, 'object');
    console.log(resp.body);
}
```

```js
{
    "self": "http://localhost:7474/db/data/node/12345678",
    "labels": "http://localhost:7474/db/data/node/12345678/labels",
    "properties": "http://localhost:7474/db/data/node/12345678/properties",
    // ...
    "metadata": {
        "id": 12345678,
        "labels": [
            "User",
            "Admin"
        ]
    },
    "data": {
        "name": "Alice Smith",
        "email": "alice@example.com",
        "emailVerified": true,
        "passwordHash": "..."
    }
}
```

Other options:

- **`headers`**: optional custom [HTTP headers](#headers) to send with this request. These will add onto the default `GraphDatabase` `headers`, but also override any that overlap.

- **`body`**: an optional request body, e.g. for `POST` and `PUT` requests. This gets serialized to JSON.

Requests and responses can also be **streamed** for maximum performance. The `http` method returns a [Request.js](https://github.com/request/request) instance, which is a [`DuplexStream`](https://nodejs.org/api/stream.html#stream_class_stream_duplex) combining both the writeable request stream and the readable response stream.

*(Request.js provides a number of benefits over the native HTTP
[`ClientRequest`](http://nodejs.org/api/http.html#http_class_http_clientrequest) and [`IncomingMessage`](http://nodejs.org/api/http.html#http_http_incomingmessage) classes, e.g. proxy support,
gzip decompression, simpler writes, and a single unified `'error'` event.)*

If you want to stream the request, be sure not to pass a `body` option. And if you want to stream the response (without having it buffer in memory), be sure not to pass a callback. You can stream the request without streaming the response, and vice versa.

Streaming the response implies the `raw` option above: nodes and relationships are *not* transformed (as even JSON isn't parsed), and 4xx and 5xx responses are *not* treated as errors.

```js
var req = db.http({
    method: 'GET',
    path: '/db/data/node/12345678',
});

req.on('error', function (err) {
    // Handle the error somehow. The default behavior is:
    throw err;
});

req.on('response', function (resp) {
    assert.equal(resp.statusCode, 200);
    assert.equal(typeof resp.headers, 'object');
    assert.equal(typeof resp.body, 'undefined');
});

var body = '';

req.on('data', function (chunk) {
    body += chunk;
});

req.on('end', function () {
    body = JSON.parse(body);
    console.log(body);
});
```


## Errors

To achieve robustness in your app, it's vitally important to handle errors precisely.


## Tuning

(TODO)


## Management

(TODO)

- change password
- get labels, etc.


## Help

Questions, comments, or other general discussion? **[Google Group »](https://groups.google.com/group/node-neo4j)**

Bug reports or feature requests? **[GitHub Issues »](https://github.com/thingdom/node-neo4j/issues)**

You can also try **[Gitter](https://gitter.im/thingdom/node-neo4j)**, **[Stack Overflow](http://stackoverflow.com/search?q=node-neo4j)** or **[Slack](https://neo4j-users.slack.com/messages/neo4j-javascript)** ([sign up here](http://neo4j-users-slack-invite.herokuapp.com/)).


## Contributing

[See **CONTRIBUTING.md** »](./CONTRIBUTING.md)


## History

[See **CHANGELOG.md** »](./CHANGELOG.md)


## License

Copyright © 2016 **[Aseem Kishore](https://github.com/aseemk)** and [contributors](https://github.com/thingdom/node-neo4j/graphs/contributors).

This library is licensed under the **[Apache License, Version 2.0](./LICENSE)**.
