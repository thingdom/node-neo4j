# Node-Neo4j API v2

This is a rough, work-in-progress redesign of the node-neo4j API.

- [General](#general)
- [Core](#core)
- [Auth](#auth)
- [HTTP](#http)
- [Objects](#objects)
- [Cypher](#cypher)
- [Transactions](#transactions)
- [Errors](#errors)
- [Schema](#schema)
- [Legacy Indexing](#legacy-indexing)


## General

This driver will aim to generally be stateless and functional,
inspired by [React.js](http://facebook.github.io/react/).
Some context doesn't typically change, though (e.g. the URL to the database),
so this driver supports maintaining such context as simple state.

This driver continues to accept standard Node.js callbacks of the form
`function (result, error)`, for straightforward development using standard
Node.js control flow tools and libraries.

In addition, however, this driver also supports streaming use cases now.
Where specified, callbacks can be omitted to have get back streams instead.
And importantly, in that case, this driver will take special care not to
buffer results in memory, ensuring high performance and low memory usage.

This v2 driver converges on an options-/hash-based API for most/all methods.
This both conveys clearer intent and leaves room for future additions.
For the sake of this rough spec, you can assume most options are optional,
but this will be documented more precisely in the final API documentation.


## Core

**Let me make a "connection" to the database.**

```js
var neo4j = require('neo4j');

var db = new neo4j.GraphDatabase({
    url: 'http://localhost:7474',
    auth: null,     // optional; see below for more details
    headers: {},    // optional defaults, e.g. User-Agent
    proxy: null,    // optional URL
    agent: null,    // optional http.Agent instance, for custom socket pooling
});
```

To specify auth credentials, the username and password can be provided either
directly in the URL, e.g. `'http://user:pass@localhost:7474'`,
or via an `auth` option, which can either be a `'username:password'` string
or a `{username, password}` object. The auth option takes precedence.

If credentials are given in any form, they will be normalized to a
`{username, password}` object and set as the `auth` property on the
constructed `GraphDatabase` instance.
In addition, the `url` property will have its credentials cleared if an `auth`
option was provided as well.
An empty string/object `auth` can be provided to clear auth in this way;
the `auth` property will be normalized to `null` in this case.

The current v1 of the driver is hypermedia-driven, so it discovers the
`/db/data` endpoint. We may hardcode that in v2 for efficiency and simplicity,
but if we do, do we need to make that customizable/overridable too?


## Auth

**Let me manage database authentication.**

Note that this section only matters for *managing* auth, not *specifying* it.

```js
function cbBool(err, bool) {}
function cbDone(err) {}

db.checkPasswordChangeNeeded(cbBool);
db.changePassword({password}, cbDone);
```

For convenience, changing the password will automatically update the `auth`
property on the `GraphDatabase` instance, so that subsequent requests will work.


## HTTP

**Let me make arbitrary HTTP requests to the REST API.**

This will allow callers to make any API requests; no one will be blocked by
this driver not supporting a particular API.

It'll also allow callers to interface with arbitrary Neo4j plugins
(e.g. [neo4j-spatial](http://neo4j-contrib.github.io/spatial/#spatial-server-plugin)),
even custom ones.

```js
function cb(err, body) {}

var req = db.http({method, path, headers, body, raw}, cb);
```

This method returns a [`Request.js`][] instance, which is a duplex stream
to and from which both request and response data can be streamed.

(`Request.js` provides a number of benefits over the native HTTP
[`ClientRequest`][] and [`IncomingMessage`][] classes, such as proxy support,
gzip decompression, simpler writes, and a single, unified `'error'` event.)

[`Request.js`]: https://github.com/request/request
[`ClientRequest`]: http://nodejs.org/api/http.html#http_class_http_clientrequest
[`IncomingMessage`]: http://nodejs.org/api/http.html#http_http_incomingmessage

In addition, if a callback is given, it will be called with the final result.
By default, this result will be the HTTP response body (parsed as JSON),
with nodes and relationships transformed to
[`Node` and `Relationship` objects](#objects),
or an [`Error` object](#errors) both if there was a native error (e.g. DNS)
or if the HTTP status code is `4xx` or `5xx`.

Alternately, `raw: true` can be passed to have the callback receive the full
HTTP response, with `statusCode`, `headers`, and `body` properties.
The `body` will still be parsed as JSON, but nodes, relationships, and errors
will *not* be transformed to node-neo4j objects in this case.
In addition, `4xx` and `5xx` status code will *not* yield an error.


## Objects

**Give me useful objects, instead of raw JSON.**

Transform the Neo4j REST API's raw JSON format for nodes and relationships
into useful `Node` and `Relationship` objects.
These objects don't have to do anything / have any mutating methods;
they're just container objects that serve to organize information.

```coffee
class Node {_id, labels, properties}
class Relationship {_id, type, properties, _fromId, _toId}
```

TODO: Transform path JSON into `Path` objects too?
We have this in v1, but is it really useful and functional these days?
E.g. see [issue #57](https://github.com/thingdom/node-neo4j/issues/57).

Importantly, using Neo4j's native IDs is strongly discouraged these days,
so v2 of this driver makes that an explicit private property.
It's still there if you need it, e.g. for the old-school traversal API.

That extends to relationships: they explicitly do *not* link to `Node`
*instances* anymore (since that data is frequently not available), only IDs.
Those IDs are thus private too.

Also importantly, there's no more notion of persistence or updating
(e.g. no more `save()` method) in this v2 API.
If you want to update data and persist it back to Neo4j,
you do that the same way as you would without these objects.
*This driver is <strong>not</strong> an ORM/OGM.
Those problems must be solved separately.*

It's similarly no longer possible to create or get an instance of either of
these classes that represents data that isn't persisted yet (like the current
v1's *synchronous* `db.createNode()` method returns).
These classes are only instantiated internally, and only returned async'ly
from database responses.


## Cypher

**Let me make simple, parametrized Cypher queries.**

```js
function cb(err, results) {}

var stream = db.cypher({query, params, headers, lean}, cb);

// Alternate simple version -- no params, no headers, not lean:
var stream = db.cypher(query, cb);
```

If a callback is given, it'll be called with the array of results,
or an error if there is one.
Alternately, the results can be streamed back by omitting the callback.
In that case, a stream will be returned, which will emit a `data` event
for each result, or an `error` event if there is one.
In both cases, each result will be a dictionary from column name to
row value for that column.

In addition, by default, nodes and relationships will be transformed to
`Node` and `Relationship` objects.
If you don't need the full knowledge of node and relationship metadata
(labels, types, native IDs), you can bypass that by specifying `lean: true`,
which will return just property data, for a potential performance gain.

TODO: Should we formalize the streaming case into a documented Stream class?
Or should we just link to cypher-stream?

TODO: Should we allow access to other underlying data formats, e.g. "graph"?


## Batching

**Let me make multiple, separate Cypher queries in one network request.**

```js
function cbMany(err, arraysOfResults) {}

var streams = db.cypher({queries, headers}, cbMany);

// Alternate simple version -- no custom headers:
var streams = db.cypher(queries, cbMany);
```

In both cases, `queries` is an array of queries, where each query can be a
`{query, params, lean}` object or a simple string.

**Important:** batch queries are executed transactionally —
either they all succeed, or they all fail.

If a callback is given, it'll be called with an array containing an array of
results for each query (in matching order), or an error if there is any.
Alternately, the results can be streamed back by omitting the callback.
In that case, an array will be returned, containing a stream for each query
(in matching order).

TODO: Is it valuable to return a stream of results *across all queries*?


## Transactions

**Let me make multiple queries, across multiple network requests,
all within a single transaction.**

```js
var tx = db.beginTransaction();
```

This method is named "begin" instead of "create" to reflect that it returns
immediately, and has not actually persisted anything to the database yet.

This method returns a `Transaction` object, which mainly just encapsulates the
state of a "transaction ID" returned by Neo4j from the first query.
In addition, though, `Transaction` instances expose helpful properties to let
you know a transaction's precise state, e.g. whether it was automatically
rolled back by Neo4j due to a fatal error.
This precise state tracking also lets this driver prevent predictable errors,
which may be signs of code bugs, and provide more helpful error messaging.

```coffee
class Transaction {_id, expiresAt, expiresIn, state}
# `expiresAt` is a Date, while `expiresIn` is a millisecond count.
# `state` is one of 'open', 'pending', 'committed, 'rolled back', or 'expired',
# all of which are constant properties on instances, e.g. `STATE_ROLLED_BACK`.
```

```js
function cbResults(err, results) {}
function cbDone(err) {}

var stream = tx.cypher({query, params, headers, lean, commit}, cbResults);

tx.commit(cbDone);
tx.rollback(cbDone);
tx.renew(cbDone);
```

The transactional `cypher` method is just like the regular `cypher` method
(e.g. it supports simple strings, as well as batching),
except that it supports an additional `commit` option, which can be set to
`true` to automatically attempt to commit the transaction with this query.

Otherwise, transactions can be committed and rolled back independently.
They can also be explicitly renewed, as Neo4j expires them if idle too long,
but every query in a transaction implicitly renews the transaction as well.


## Errors

**Throw meaningful and semantic errors.**

Background reading — a huge source of inspiration that informs much of the
API design here:

http://www.joyent.com/developers/node/design/errors

Neo4j v2 provides excellent error info for (transactional) Cypher requests:

http://neo4j.com/docs/stable/status-codes.html

Essentially, errors are grouped into three "classifications":
**client errors**, **database errors**, and **transient errors**.
There are additional "categories" and "titles", but the high-level
classifications are just the right level of granularity for decision-making
(e.g. whether to convey the error to the user, fail fast, or retry).

```json
{
    "code": "Neo.ClientError.Statement.EntityNotFound",
    "message": "Node with id 741073"
}
```

Unfortunately, other endpoints return errors in a completely different format
and style. E.g.:

- [404 `NodeNotFoundException`](http://neo4j.com/docs/stable/rest-api-nodes.html#rest-api-get-non-existent-node)
- [409 `OperationFailureException`](http://neo4j.com/docs/stable/rest-api-nodes.html#rest-api-nodes-with-relationships-cannot-be-deleted)
- [400 `PropertyValueException`](http://neo4j.com/docs/stable/rest-api-node-properties.html#rest-api-property-values-can-not-be-null)
- [400 `BadInputException` w/ nested `ConstraintViolationException` and `IllegalTokenNameException`](http://neo4j.com/docs/stable/rest-api-node-labels.html#rest-api-adding-a-label-with-an-invalid-name)

```json
{
    "exception": "BadInputException",
    "fullname": "org.neo4j.server.rest.repr.BadInputException",
    "message": "Unable to add label, see nested exception.",
    "stacktrace": [
        "org.neo4j.server.rest.web.DatabaseActions.addLabelToNode(DatabaseActions.java:328)",
        "org.neo4j.server.rest.web.RestfulGraphDatabase.addNodeLabel(RestfulGraphDatabase.java:447)",
        "java.lang.reflect.Method.invoke(Method.java:606)",
        "org.neo4j.server.rest.transactional.TransactionalRequestDispatcher.dispatch(TransactionalRequestDispatcher.java:139)",
        "java.lang.Thread.run(Thread.java:744)"
    ],
    "cause": {...}
}
```

One important distinction is that (transactional) Cypher errors *don't* have
any associated HTTP status code (since the results are streamed),
while the "legacy" exceptions do.
Fortunately, HTTP 4xx and 5xx status codes map almost directly to
"client error" and "database error" classifications, while
"transient" errors can be detected by name.

So when it comes to designing this driver's v2 error API,
there are two open questions:

1.  Should this driver abstract away this discrepancy in Neo4j error formats,
    and present a uniform error API across the two?
    Or should it expose these two different formats?

2.  Should this driver return standard `Error` objects decorated w/ e.g. a
    `neo4j` property? Or should it define its own `Error` subclasses?

The current design of this API chooses to present a uniform (but minimal) API
using `Error` subclasses. Importantly:

- The subclasses correspond to the client/database/transient classifications
  mentioned above, for easy decision-making via either the `instanceof`
  operator or the `name` property.

- Special care is taken to provide `message` and `stack` properties rich in
  info, so that no special serialization is needed to debug production errors.
  That is, simply logging the `stack` (as most error handlers tend to do)
  should get you meaningful and useful data.

- Structured info returned by Neo4j is also available on the `Error` instances
  under a `neo4j` property, for deeper introspection and analysis if desired.

```coffee
class Error {name, message, stack, neo4j}

class ClientError extends Error
class DatabaseError extends Error
class TransientError extends Error
```

Note that these class names do *not* have a `Neo4j` prefix, since they'll only
be exposed via this driver's `module.exports`, but for convenience, instances'
`name` properties *do* have a `neo4j.` prefix, e.g. `neo4j.ClientError`.


## Schema

**Let me manage the database schema: labels, indexes, and constraints.**

Much of this is already possible with Cypher, but a few things aren't
(e.g. listing all labels).
Even for the things that are, this driver can provide convenience methods
for those boilerplate Cypher queries.

### Labels

```js
function cb(err, labels) {}

db.getLabels(cb);
```

Methods to manipulate labels on nodes are purposely *not* provided,
as those start to get into the territory of operations that should really be
performed atomically within a Cypher query.
(E.g. labels should generally be set on nodes right when they're created.)
Conveniences for those kinds of things are perfect for an ORM/OGM to solve.

Labels are simple strings.

### Indexes

```js
function cbOne(err, index) {}
function cbMany(err, indexes) {}
function cbBool(err, bool) {}
function cbDone(err) {}

db.getIndexes(cbMany);              // across all labels
db.getIndexes({label}, cbMany);     // for a particular label
db.hasIndex({label, property}, cbBool);
db.createIndex({label, property}, cbOne);
    // callback receives null if this index already exists
db.dropIndex({label, property}, cbBool);
    // callback receives true if this index existed and was dropped,
    // false if it didn't exist in the first place
```

Returned indexes are minimal `Index` objects:

```coffee
class Index {label, property}
```

TODO: Neo4j's REST API actually takes and returns *arrays* of properties,
but AFAIK, all indexes today only deal with a single property.
Should multiple properties be supported?

TODO: Today, there's no need for a `db.getIndex()` method, since the parameters
you need to fetch an index are the same ones that are returned.
But if Neo4j adds extra info to the response (e.g. online/offline status),
we should add that method, along with that extra info in our `Index` class.

### Constraints

The only constraint type implemented by Neo4j today is the uniqueness
constraint, so this API assumes that.
Because of that, it's possible that this API may have to break whenever new
constraint types are added (whatever they may be).

```js
function cbOne(err, constraint) {}
function cbMany(err, constraints) {}
function cbBool(err, bool) {}
function cbDone(err) {}

db.getConstraints(cbMany);              // across all labels
db.getConstraints({label}, cbMany);     // for a particular label
db.hasConstraint({label, property}, cbBool);
db.createConstraint({label, property}, cbOne);
    // callback receives null if this constraint already exists
db.dropConstraint({label, property}, cbDone);
    // callback receives true if this constraint existed and was dropped,
    // false if it didn't exist in the first place
```

Returned constraints are minimal `Constraint` objects:

```coffee
class Constraint {label, property}
```

TODO: Neo4j's REST API actually takes and returns *arrays* of properties,
but uniqueness constraints today only deal with a single property.
Should multiple properties be supported?

TODO: Today, there's no need for a `db.getConstraint()` method, since the
parameters you need to fetch a constraint are the same ones that are returned.
But if Neo4j adds extra info to the response (e.g. online/offline status),
we should add that method, along with that extra info in our `Constraint` class.

### Misc

```js
function cbKeys(err, keys) {}
function cbTypes(err, types) {}

db.getPropertyKeys(cbKeys);
db.getRelationshipTypes(cbTypes);
```


## Legacy Indexing

Neo4j v2's constraint-based indexing has yet to implement much of the
functionality provided by Neo4j v1's legacy indexing (e.g. relationships,
support for arrays, fulltext indexing).
This driver thus provides legacy indexing APIs.

### Management

```js
function cbOne(err, index) {}
function cbMany(err, indexes) {}
function cbDone(err) {}

db.getLegacyNodeIndexes(cbMany);
db.getLegacyNodeIndex({name}, cbOne);
db.createLegacyNodeIndex({name, config}, cbOne);
db.deleteLegacyNodeIndex({name}, cbDone);

db.getLegacyRelationshipIndexes(cbMany);
db.getLegacyRelationshipIndex({name}, cbOne);
db.createLegacyRelationshipIndex({name, config}, cbOne);
db.deleteLegacyRelationshipIndex({name}, cbDone);
```

Both returned legacy node indexes and legacy relationship indexes are
minimal `LegacyIndex` objects:

```coffee
class LegacyIndex {name, config}
```

The `config` property is e.g. `{provider: 'lucene', type: 'fulltext'}`;
[full documentation here](http://neo4j.com/docs/stable/indexing-create-advanced.html).

### Simple Usage

```js
function cbOne(err, node_or_rel) {}
function cbMany(err, nodes_or_rels) {}
function cbDone(err) {}

db.addNodeToLegacyIndex({name, key, value, _id}, cbOne);
db.getNodesFromLegacyIndex({name, key, value}, cbMany);     // key-value lookup
db.getNodesFromLegacyIndex({name, query}, cbMany);          // arbitrary Lucene query
db.removeNodeFromLegacyIndex({name, key, value, _id}, cbDone);  // key, value optional

db.addRelationshipToLegacyIndex({name, key, value, _id}, cbOne);
db.getRelationshipsFromLegacyIndex({name, key, value}, cbMany);     // key-value lookup
db.getRelationshipsFromLegacyIndex({name, query}, cbMany);          // arbitrary Lucene query
db.removeRelationshipFromLegacyIndex({name, key, value, _id}, cbDone);  // key, value optional
```

### Uniqueness

Neo4j v1's legacy indexing provides a uniqueness constraint for
adding (existing) and creating (new) nodes and relationships.
It has two modes:

- "Get or create": if an existing node or relationship is found for the given
  key and value, return it, otherwise add this node or relationship
  (creating it if it's new).

- "Create or fail": if an existing node or relationship is found for the given
  key and value, fail, otherwise add this node or relationship
  (creating it if it's new).

For adding existing nodes or relationships, simply pass `unique: true` to the
`add` method.

```js
function cb(err, node_or_rel) {}

db.addNodeToLegacyIndex({name, key, value, _id, unique: true}, cb);
db.addRelationshipToLegacyIndex({name, key, value, _id, unique: true}, cb);
```

This uses the "create or fail" mode.
It's hard to imagine a real-world use case for "get or create" when adding
existing nodes, but please offer feedback if you have one.

For creating new nodes or relationships, the `create` method below corresponds
with "create or fail", while `getOrCreate` corresponds with "get or create":

```js
function cb(err, node_or_rel) {}

db.createNodeFromLegacyIndex({name, key, value, properties}, cb);
db.getOrCreateNodeFromLegacyIndex({name, key, value, properties}, cb);

db.createRelationshipFromLegacyIndex({name, key, value, type, properties, _fromId, _toId}, cb);
db.getOrCreateRelationshipFromLegacyIndex({name, key, value, type, properties, _fromId, _toId}, cb);
```

### Auto-Indexes

Neo4j provides two automatic legacy indexes:
`node_auto_index` and `relationship_auto_index`.
Instead of hardcoding those index names in your app,
Neo4j provides separate legacy auto-indexing APIs,
which this driver exposes as well.

The APIs are effectively the same as the above;
just replace `LegacyIndex` with `LegacyAutoIndex` in all method names,
then omit the `name` parameter.

```js
function cbOne(err, node_or_rel) {}
function cbMany(err, nodes_or_rels) {}

db.getNodesFromLegacyAutoIndex({key, value}, cbMany);   // key-value lookup
db.getNodesFromLegacyAutoIndex({query}, cbMany);        // arbitrary Lucene query
db.createNodeFromLegacyAutoIndex({key, value, properties}, cbOne);
db.getOrCreateNodeFromLegacyAutoIndex({key, value, properties}, cbOne);

db.getRelationshipsFromLegacyAutoIndex({key, value}, cbMany);   // key-value lookup
db.getRelationshipsFromLegacyAutoIndex({query}, cbMany);        // arbitrary Lucene query
db.createRelationshipFromLegacyAutoIndex({key, value, type, properties, _fromId, _toId}, cbOne);
db.getOrCreateRelationshipFromLegacyAutoIndex({key, value, type, properties, _fromId, _toId}, cbOne);
```
