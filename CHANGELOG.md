## Version 2.0.0

node-neo4j v2 is a ground-up rewrite of node-neo4j, partly to take advantage of Neo4j 2.0's re-design, and partly to incorporate lessons learned from v1.

node-neo4j v2's big new features and changes are:

- An emphasis on **Cypher** now (no more individual CRUD methods like v1's `db.createNode`). For anything non-trivial, Cypher is much more robust and expressive, so writing it directly is highly encouraged.

- Support for Cypher **transactions** and **batching**, as well as arbitrary **HTTP requests** (including streaming support) and **custom headers**.

- First-class support for Neo4j 2.0 **labels**, **schema indexes**, and **constraints**, as well as Neo4j 2.2's **password-based auth**.

- Much better **error handling**, differentiating between **client**, **server**, and **transient** errors.

- Much better **test coverage**.

- An **options-based API** now, rather than multiple parameters per function, for better readability and more extensibility.

For details on all these features and more, be sure to read through the **[readme](./README.md)**.

### Migrating from v1

If you're currently running node-neo4j v1, you may have to make some significant changes to your code, but hopefully the above features make it worth it. =)

Simple changes:

- `db.query(query, params, callback)` is now `db.cypher({query, params}, callback)`

- `node.id` and `rel.id` are now `node._id` and `rel._id`

    - This is because using these Neo4j internal IDs is officially discouraged now. Better to use a unique property instead (e.g. `username` or `uuid`).

- `node.data` and `rel.data` are now `node.properties` and `rel.properties`

Removed CRUD methods (use Cypher instead):

- `db.createNode` and `node.createRelationshipTo`/`From`

- `db.getNodeById` and `db.getRelationshipById`

- `node.getRelationships` and `node.getRelationshipNodes`

- `node.incoming`, `node.outgoing`, `node.all`, and `node.path`

- `node.save` and `rel.save`

    - In general, `Node` and `Relationship` instances are no longer "stateful". Instead of making changes to the database by modifying properties on these instances and calling `save`, just make changes via Cypher directly. Much more robust, precise, and expressive. Note in particular that [`SET node += {props}`](http://neo4j.com/docs/stable/query-set.html#set-adding-properties-from-maps) lets you update some properties without overwriting others.

- `node.exists` and `rel.exists`

    - Since `Node` and `Relationship` instances are no longer stateful, node-neo4j v2 only ever returns instances for data returned from Neo4j. So these nodes and relationships _always_ "exist" (at least, at the time they're returned).

- `node.del(ete)` and `rel.del(ete)`

Removed legacy index management (use schema indexes instead):

- `db.createNodeIndex` and `db.createRelationshipIndex`

- `db.getNodeIndexes` and `db.getRelationshipIndexes`

- `db.getIndexedNode(s)` and `db.getIndexedRelationship(s)`

- `db.queryNodeIndex` and `db.queryRelationshipIndex`

- `db.deleteNodeIndex` and `db.deleteRelationshipIndex`

- `node.(un)index` and `rel.(un)index`

Removed miscellaneous:

- `rel.start` and `rel.end`

    - These used to be full Node instances, but it's no longer efficient to load full node data for all relationships by default, so only `rel._fromId` and `rel._toId` exist now. Expand your Cypher query to return full nodes if you need them.

- `Path` class

    - For similar reasons as `rel.start` and `rel.end`. Expand your Cypher query to return [`NODES(path)`](http://neo4j.com/docs/stable/query-functions-collection.html#functions-nodes) or [`RELATIONSHIPS(path)`](http://neo4j.com/docs/stable/query-functions-collection.html#functions-relationships) if you need them.

- `db.execute` (for [Gremlin](http://gremlin.tinkerpop.com/) scripts)

    - Gremlin has been dropped as a default plugin in Neo4j 2.x, and Cypher is clearly the recommended query language going forward. If you do need Gremlin support, you can always make [HTTP requests](./README.md#http--plugins) to the [Gremlin endpoint](https://github.com/thinkaurelius/neo4j-gremlin-plugin) directly.

- `db.reviveJSON` and `db.fromJSON`

    - We may add these back if needed, but for now, since `Node` and `Relationship` instances are no longer stateful (they don't even have any public methods), reviving JSON isn't really needed. You can still `JSON.stringify` nodes and relationships, and you should be able to use parsed JSON objects directly.

- [Streamline futures](https://github.com/Sage/streamlinejs#futures) (TODO: Promises instead?)

    - This library is no longer written in Streamline, so methods no longer return Streamline futures. If your app isn't written in Streamline, this likely never mattered to you. But even if your app _is_ written in Streamline, this change may not matter to you, as Streamline 1.0 lets you call [_any_ async function](https://github.com/Sage/streamlinejs/issues/181) with `!_`.

**[node-neo4j-template PR #18](https://github.com/aseemk/node-neo4j-template/pull/18)** is a good model for the changes needed (most notably commit [`bbf8e86`](https://github.com/aseemk/node-neo4j-template/pull/18/commits/bbf8e865d99888bdfeed86c61ea5f5f6ad611981)). Take a look through that, and if you run into any issues migrating your own code, feel free to [reach out for help](./README.md#help). Good luck!


## Version 1.x.x

See the full **[v1 changelog »](https://github.com/thingdom/node-neo4j/blob/v1/CHANGELOG.md)**
