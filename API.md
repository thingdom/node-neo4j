# Node-Neo4j API

This is the API documentation for the **[node-neo4j][]** library. Follow that
link for general info, installation instructions, and more.

[node-neo4j]: https://github.com/thingdom/node-neo4j

This API documentation is fairly self-explanatory, but here are some notes:

- When you `require('neo4j')`, all you get back is a reference to the
  **[`GraphDatabase` class](classes/GraphDatabase.html)**, so start there.

- The `_` parameter in all method signatures signifies an async callback.
  All async callbacks are of the standard Node form `(err, result)`.

- All async methods that say they "return" something actually pass their
  results via that async callback. It's just simpler to document those values
  as standard "return" values.

- But, all async methods actually do have true return values -- they all
  return Streamline *[futures][]*. You don't need to worry about these at all
  if you don't want to.

[futures]: https://github.com/Sage/streamlinejs#futures

If anything else needs explanation, please [file an issue][issues].

[issues]: https://github.com/thingdom/node-neo4j/issues

This API documentation is generated via the excellent [Codo][] library. A big
thanks to [@netzpirat][] for the great work and support!

[Codo]: https://github.com/netzpirat/codo
[@netzpirat]: https://github.com/netzpirat
