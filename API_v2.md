# Node-Neo4j API v2

Scratchpad for designing a v2 of this library.

For convenience, the code snippets below are written in
[CoffeeScript](http://coffeescript.org/) and
[Streamline](https://github.com/Sage/streamlinejs).
Essentially, underscores (`_`) represent standard Node.js `(result, error)`
callbacks, and "return" and "throw" refer to those callback args.

These thoughts are written as scenarios followed by code snippets.

Sections:

- [General](#general)
- [Core](#core)
- [HTTP](#http)
- [Objects](#objects)
- [Cypher](#cypher)
- [Transactions](#transactions)
- [Errors](#errors)


## General

This driver will aim to generally be stateless and functional,
inspired by [React.js](http://facebook.github.io/react/).
Some context doesn't typically change, though (e.g. the URL to the database),
so this driver supports maintaining such context as simple state.

This driver is geared towards the standard Node.js callback convention
mentioned above, but streams are now also returned wherever possible.
This allows both straightforward development using standard Node.js control
flow tools and libraries, while also supporting more advanced streaming usage.
You can freely use either, without worrying about the other.

Importantly, if no callback is given (implying that the caller is streaming),
this driver will take care to not buffer any content in memory for callbacks,
ensuring high performance and low memory usage.

This v2 driver converges on an options-/hash-based API for most/all methods.
This both conveys clearer intent and leaves room for future additions.


## Core

**Let me make a "connection" to the database.**

```coffee
neo4j = require 'neo4j'

db = new neo4j.GraphDatabase
    url: 'http://localhost:7474'
    headers: ...    # optional defaults, e.g. User-Agent
    proxy: ...      # optional
```

An upcoming version of Neo4j will likely add native authentication.
We already support HTTP Basic Auth in the URL, but we may then need to add
ways to manage the auth (e.g. generate and reset tokens).

The current v1 of the driver is hypermedia-driven, so it discovers the
`/db/data` endpoint. We may hardcode that in v2 for efficiency and simplicity,
but if we do, do we need to make that customizable/overridable too?


## HTTP

**Let me make arbitrary HTTP requests to the REST API.**

This will allow callers to make any API requests; no one will be blocked by
this driver not supporting a particular API.

It'll also allow callers to interface with arbitrary plugins,
including custom ones.

```coffee
db.http {method, path, headers, body}, _
```

This method will immediately return the raw, pipeable HTTP response stream,
and "return" (via callback) the full HTTP response when it's finished.
The body will be parsed as JSON, and nodes and relationships will be
transformed into `Node` and `Relationship` objects (see below).

Importantly, we don't want to leak the implementation details of which HTTP
library we use. Both [request](https://github.com/request/request) and
[SuperAgent](http://visionmedia.github.io/superagent/#piping-data) are great;
it'd be nice to experiment with both (e.g. SuperAgent supports the browser).
Does this mean we should do anything special when returning HTTP responses?
E.g. should we document our own minimal HTTP `Response` interface that's the
common subset of both libraries?

Also worth asking: what about streaming the response JSON?
It looks like [Oboe.js](http://oboejs.com/) supports reading an existing HTTP
stream ([docs](http://oboejs.com/api#byo-stream)), but not in the browser.
Is that fine?


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

```coffee
db.cypher {query, params, headers, raw}, _
```

This method will immediately return a pipeable "results" stream (a `data`
event will be emitted for each result row), then "return" (via callback)
the full results array at the end (similar to the `http()` method).
Each result row will be a dictionary from column name to the row's value for
that column.

By default, nodes and relationships will be transformed to `Node` and
`Relationship` objects.
To do that, though, requires a heavier data format over the wire.
If you don't need the full knowledge of node and relationship metadata
(labels, types, native IDs), you can bypass this by passing `raw: true`
for a potential performance gain.

If there's an error, the "results" stream will emit an `error` event,
as well as "throw" (via callback) the error.

TODO: Should we formalize the "results" stream into a documented class?

TODO: Should we allow access to other underlying data formats, e.g. "graph"?


## Transactions

**Let me make multiple queries, across multiple network requests,
all within a single transaction.**

This is the trickiest part of the API to design.
I've tried my best to design this using the use cases we have at FiftyThree,
but it's very hard to know whether this is designed well for a broader set of
use cases without having more experience or feedback.

Example use case: complex delete.
I want to delete an image, which has some image-specific business logic,
but in addition, I need to delete any likes and comments on the image.
Each of those has its own specific business logic (which may also be
recursive), so our code can't capture everything in a single query.
Thus, we need to make one query to delete the comments and likes (which may
actually be multiple queries, as well), then a second one to delete the image.
We want to do all of that transactionally, so that if any one query fails,
we abort/rollback and either retry or report failure to the user.

Given a use case like that, this API is optimized for **one query per network
request**, *not* multiple queries per network request ("batching").
I *think* batching is always an optimization (never a true *requirement*),
so it could always be achieved automatically under-the-hood by this driver
(e.g. by waiting until the next event loop tick to send the actual queries).
Please provide feedback if you disagree!

```coffee
tx = db.beginTransaction {...}      # any options needed?
```

This method returns a `Transaction` object, which mainly just encapsulates the
state of a "transaction ID" returned by Neo4j from the first query.

This method is named "begin" instead of "create" to reflect that it returns
immediately, and has not actually persisted anything to the database yet.

```coffee
class Transaction {_id}

tx.cypher {query, params, headers, raw, commit}, _
tx.commit _
tx.rollback _
```

The transactional `cypher` method is just like the regular `cypher` method,
except that it supports an additional `commit` option, which can be set to
`true` to automatically attempt to commit the transaction after this query.

Otherwise, transactions can be committed and rolled back independently.

TODO: Any more functionality needed for transactions?
There's a notion of expiry, and the expiry timeout can be reset by making
empty queries; should a notion of auto "renewal" (effectively, a higher
timeout than the default) be built-in for convenience?


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

- And all info returned by Neo4j is also available on the `Error` instances
  under a `neo4j` property, for deeper introspection and analysis if desired.

```coffee
class Error {name, message, stack, neo4j}

class ClientError extends Error
class DatabaseError extends Error
class TransientError extends Error
```

TODO: Should we name these classes with a `Neo4j` prefix?
They'll only be exposed via this driver's `module.exports`, so it's not
technically necessary, but that'd allow for e.g. destructuring.
