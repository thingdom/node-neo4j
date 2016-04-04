## Version 2.0.0

node-neo4j v2 is a ground-up rewrite of node-neo4j, partly to take advantage of Neo4j 2.0's re-design, and partly to incorporate lessons learned from v1.

node-neo4j v2's big new features and changes are:

- An emphasis on **Cypher** now (renamed from ~~`db.query`~~ to `db.cypher`); no more ~~individual CRUD methods~~ (like v1's ~~`db.createNode`~~, etc.). For anything non-trivial, Cypher is much more expressive and robust, so writing it directly is highly encouraged.

- Support for Cypher **transactions** and **batching**, as well as arbitrary **HTTP requests** (including streaming support) and **custom headers**.

- First-class support for Neo4j 2.0 **labels**, **schema indexes**, and **constraints**, as well as Neo4j 2.2's **password auth**.

- Much better **error handling**, differentiating between **client**, **server**, and **transient** errors.

- Much better **test coverage**.

- An **options-based API** now, rather than multiple parameters per function, for better readability and more extensibility.

For details on all these features and more, be sure to read through the **[readme](./README.md)**.

### Migrating from v1

TODO


## Version 1.x.x

See the full **[v1 changelog »](https://github.com/thingdom/node-neo4j/blob/v1/CHANGELOG.md)**
