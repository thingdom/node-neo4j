## Unreleased

  - **New:** this library is now compiled under Streamline's "standalone"
    mode, which means Streamline is no longer a runtime dependency.

  - Minor: assert that Cypher queries are strings; sending an object seems to
    trigger a Neo4j bug. (Pull [#94][]; thanks [@tasinet][]!)

  - Minor: Re-compile w/ the latest Streamline, to improve error stack traces.
    (Issue [#139])

[#94]: https://github.com/thingdom/node-neo4j/pull/94
[@tasinet]: https://github.com/tasinet
[#139]: https://github.com/thingdom/node-neo4j/issues/139

## Version 1.1.0 — November 17, 2013

  - **New:** `GraphDatabase` `queryRelationshipIndex()` method, similar to the
    existing `queryNodeIndex()` method.

  - **New:** the `GraphDatabase` `createNodeIndex()` and
    `createRelationshipIndex()` methods now take an optional `config`
    parameter after the index name.
    See the Neo4j manual ([Configuration and fulltext indexes][]) for more.

    Both of the above were contributed by [@sarpdoruk][] — thanks!
    (Pull [#93][])

[Configuration and fulltext indexes]: http://docs.neo4j.org/chunked/stable/indexing-create-advanced.html
[@sarpdoruk]: https://github.com/sarpdoruk
[#93]: https://github.com/thingdom/node-neo4j/pull/93

  - **Fixed:** callbacks that throw (rather than async'ly propagate)
    synchronous errors are no longer called again with the error
    (issue [#76][]).

[#76]: https://github.com/thingdom/node-neo4j/issues/76

  - **New:** Source maps are now generated alongside the compiled JS, for both
    CoffeeScript and Streamline. Suh-weet!

  - **New:** nodes and relationships can now be serialized to and from JSON!
    (Issue [#75][])

    Specifically, you can now freely `JSON.stringify()` any `Node` or
    `Relationship` instance — or any object or array containing `Node` and/or
    `Relationship` instances — and the resulting string will be deserializable
    back into `Node` and/or `Relationship` instances.

    To deserialize, the `GraphDatabase` class has a new `reviveJSON()`
    instance method that can be passed as the second argument to `JSON.parse()`;
    this method will take care of the automatic transformation above.

    Example:

    ```js
    var str = JSON.stringify([node, {foo: bar: relationship}]);
    var obj = JSON.parse(str, db.reviveJSON);
    // obj[0] and obj[1].foo.bar are again Node and Relationship instances!
    ```

    This is perfect for caching, e.g. to disk or Redis. Try it out!

[#75]: https://github.com/thingdom/node-neo4j/issues/75

## Version 1.0.0 — October 2, 2013

  - ***BREAKING:*** This library no longer supports Neo4j 1.4.

  - ***BREAKING:*** `GraphDatabase::getVersion()` has been removed.
    It was only used internally for Neo4j 1.4 support;
    hopefully you had no need for it externally.

  - Otherwise, this is the same as v0.2.21 — just nailing down "v1" finally!

## Version 0.2.21 — October 2, 2013

  - New `GraphDatabase` methods to create, read, and delete node and
    relationship indexes, e.g. `createNodeIndex()`, `getNodeIndexes()`, and
    `deleteNodeIndex()` respectively for nodes.

  - New `Node` and `Relationship` `unindex()` methods to remove the current
    node or relationship from an index, optionally under the given key or
    key-value pair.

  - Both of the above were contributed by [@flipside][] — many thanks!
    (Pull [#55][])

  - The `Node` class's `createRelationshipTo()` and `createRelationshipFrom()`
    methods now support omitting the `data` parameter.
    (Issue [#87][]; thanks [@rpsirois][]!)

  - The Cypher `query()` method now guards against malformed responses, which
    may happen if Neo4j runs out of memory serving inefficient queries.
    (Issue [#71][])

[#55]: https://github.com/thingdom/node-neo4j/pull/55
[#71]: https://github.com/thingdom/node-neo4j/issues/71
[#87]: https://github.com/thingdom/node-neo4j/issues/87

[@rpsirois]: https://github.com/rpsirois

## Version 0.2.20 — April 17, 2013

  - Improved error handling: this library now catches and parses a couple of
    undocumented Neo4j error responses.

  - Simplified installation: this library's CoffeeScript-Streamline source is
    compiled to regular JavaScript pre-publish instead of post-install now.
    This means the version that's in npm is ready to use out-of-the-box now.
    This also fixes deployments to Heroku, where npm isn't available to
    modules. (Issue [#35][]; thanks [@flipside][]!)

  - Other than that, just improvements to the tests and documentation.

[#35]: https://github.com/thingdom/node-neo4j/issues/35

## Version 0.2.19 — October 1, 2012

  - No code changes, just improvements to the
    **[API documentation][api-docs]**.

## Version 0.2.18 — September 30, 2012

  - **[API documentation][api-docs]** has finally been added! Many thanks to
    [@netzpirat][] for the excellent [Codo][] tool and support. (Issue [#6][])

[api-docs]: http://coffeedoc.info/github/thingdom/node-neo4j/master/
[@netzpirat]: https://github.com/netzpirat
[Codo]: https://github.com/netzpirat/codo
[#6]: https://github.com/thingdom/node-neo4j/issues/6

## Version 0.2.17 — September 21, 2012

  - Add support for [Gremlin][] queries! This is done via a new
    `GraphDatabase::execute()` method that's similar to the Cypher
    `GraphDatabase::query()` method; see the [Gremlin tests][] for examples.
    Credit and thanks to [@sprjr][] for the implementation! (Pull [#47][])

[Gremlin]: http://gremlin.tinkerpop.com/
[Gremlin tests]: https://github.com/thingdom/node-neo4j/blob/develop/test/gremlin._coffee
[#47]: https://github.com/thingdom/node-neo4j/pull/47
[@sprjr]: https://github.com/sprjr

## Version 0.2.16 — September 11, 2012

  - Fix a regression introduced in v0.2.15 that added two extra round-trips to
    every request! Sorry about that.

  - But a major extra performance boost on top: instructs Neo4j 1.7+ to stream
    its JSON responses back. This reduces the latency of each request as well
    as Neo4j's memory usage. (Issue [#48][])

    Note that this library still collects the full response before parsing and
    returning it to your code, but this also means it requires no code changes
    from your side.

[#48]: https://github.com/thingdom/node-neo4j/issues/48

## Version 0.2.15 — September 10, 2012

  - Refactor internal code to centralize JSON transformation logic for Cypher
    queries. This adds support for returning paths now, too!
    (Issue [#22][])

  - Requests now send a User-Agent header that identifies this library and its
    version. This feature was requested by the Neo4j team so that they can
    track and analyze library usage. Cool!

  - You can now set a proxy URL for all requests. This is done by passing in
    an options hash of `{url, proxy}` to the `GraphDatabase` constructor,
    instead of just a string `url`.
    (Issue [#34][])

[#22]: https://github.com/thingdom/node-neo4j/issues/22
[#34]: https://github.com/thingdom/node-neo4j/issues/34

## Version 0.2.14 — September 10, 2012

  - Support returning arrays of nodes/relationships in Cypher (via `COLLECT`).
    (Pull [#33][]; thanks [@flipside][]!)

  - Relationships can now be indexed too, via `Relationship::index()` and
    `GraphDatabase::getIndexedRelationships()`.
    (Pull [#40][]; thanks [@flipside][]!)

  - `Node::save()` now returns the same `Node` instance via its callback.
    (Issue [#42][])

[#33]: https://github.com/thingdom/node-neo4j/pull/33
[#40]: https://github.com/thingdom/node-neo4j/pull/40
[#42]: https://github.com/thingdom/node-neo4j/issues/42

## Version 0.2.13 — June 17, 2012

  - Upgraded from Streamline 0.3 to the stable Streamline 0.4. This update
    lets us remove our 0.2.11 workaround (commit [4df4944][]) and simplify our
    package.json install script.

## Version 0.2.12 — June 14, 2012

  - HTTP Basic Auth support was broken on Node 0.6 due to a [node-request][]
    bug that's since been fixed; upgraded and indeed fixed.
    (Issue [#27][]; thanks [@flipside][] for the heads-up!)

  - Cypher queries can (and should) now be [parameterized][]! This improves
    both perf and security, especially w/ mutable Cypher coming in Neo4j 1.8.
    (Pull [#25][]; thanks [@jonpacker][]!)

[node-request]: https://github.com/mikeal/request
[#27]: https://github.com/thingdom/node-neo4j/issues/27
[@flipside]: https://github.com/flipside

[parameterized]: http://docs.neo4j.org/chunked/stable/cypher-plugin.html#cypher-plugin-api-send-queries-with-parameters
[#25]: https://github.com/thingdom/node-neo4j/pull/25
[@jonpacker]: https://github.com/jonpacker

## Version 0.2.11 — May 13, 2012

  - Tweaked the compile-on-install to be robust to the possibility that this
    library is installed alongside Streamline but not CoffeeScript. See commit
    [4df4944][] for details, and issue [isaacs/npm#2443][] for an npm change
    request that would fix this problem the proper way.

[4df4944]: https://github.com/thingdom/node-neo4j/commit/4df4944eca079d9678aebcbf2ffb57c57bf2b17b
[isaacs/npm#2443]: https://github.com/isaacs/npm/issues/2443

## Version 0.2.10 — May 8, 2012

  - Fixed a minor Node 0.6 bug when the database isn't available.
  - Changed our structure to compile the CoffeeScript-Streamline source into
    regular JS on *your* computer now as part of installation, instead of on
    *mine* as part of publishing. This way, bugfixes in the compilers can be
    picked up by you without this module needing to be republished.


## Version 0.2.9 — April 30, 2012

  - Upgraded from Streamline 0.2 to 0.3. This allows us to take advantage of
    the new `._coffee` file extension for a bit cleaner code.
  - Unfortunately, Streamline 0.3 requires Node 0.6, and the compiled code
    requires Streamline's runtime, so even though the runtime itself doesn't
    require Node 0.6, our package won't correctly install on Node 0.4 anymore.
    So we now require Node 0.6, but hopefully that's not a big deal. Let us
    know via the issue tracker if this affects you.

## Version 0.2.8 — April 25, 2012

  - Optimized the construction of new object instances in our code. This shows
    >50x improvement when creating or fetching many nodes or relationships.

## Version 0.2.7 — April 22, 2012

  - Reversed the order of `GraphDatabase::query()` from `(callback, query)` to
    `(query, callback)`, to be consistent with our other methods (#20), but
    retained backwards-compatibility -- the old style still works (it just
    logs a warning to the console). Thanks @sprjr for the nudge!

## Version 0.2.6 — April 22, 2012

  - Upgraded from CoffeeScript 1.1 to 1.3 and from Streamline 0.1 to 0.2.
  - More importantly, the published module on npm is now compiled JS! (#17)
    This means better startup performance (no just-in-time compilation) and
    more robustness (no CoffeeScript/Streamline version conflicts). This was
    achieved thanks to Streamline 0.2's new in-file directive, allowing us to
    remove the underscores from our filenames and thus `require()` calls.
    Thanks to @vjeux for bringing this to our attention.

## Version 0.2.5 — March 1, 2012

  - Added support for HTTP Basic Auth by working around the fact that Neo4j
    doesn't maintain the username and password in the URLs it returns (#7).
    Many thanks to @anatoliychakkaev for finding this and suggesting the fix.

## Version 0.2.4 — January 29, 2012

  - Updated library to support Neo4j 1.6. Still supports 1.5 and 1.4. No
    changes were actually needed, but uses the new official Cypher endpoint
    now instead of the deprecated plugin endpoint, if it's available.

## Version 0.2.3 — January 25, 2012

  - Updated library to support Neo4j 1.5. Still supports 1.4.
  - Added a GraphDatabase::getVersion(_) method. Neo4j 1.5 onwards returns the
    version number, so this method returns 1.4 for older versions of Neo4j.

## Version 0.2.2 – January 25, 2012

  - Updated `streamline` dependency to get sync stack traces!
  - Improve handling of error responses from Neo4j.

## Version 0.2.1 – September 2, 2011

  - Updated `request` dependency. ([@aseemk][])
  - Added Cypher querying and tests. ([@aseemk][])
  - Better error handling. ([@aseemk][])

## Version 0.2.0 – July 14, 2011

  - Massive overhaul of the entire library:
    - Rewrote complete library using [Streamline.js][] ([@aseemk][])
    - Massively extended test suite ([@aseemk][])
    - Implemented `Node.getRelationships` method ([@aseemk][])
    - Implemented `Node.getRelationshipNodes` method ([@aseemk][])
    - Simplified error handling ([@gasi][])
    - Split monolithic file into separate files according to classes ([@aseemk][])
    - Implemented `Node.path` method and `Path` class ([@gasi][])
    - Added `Node.createRelationshipFrom` method ([@gasi][])
    - Fixed numerous bugs ([@aseemk][] & [@gasi][])

## Version 0.1.0 – April 20, 2011

  - Changed name from _Neo4j REST client for Node.js_ to _Neo4j driver for Node_.
  - Rewrote complete library to feature an object-oriented structure.

## Version 0.0.3 – March 26, 2011

  - Updated README.

## Version 0.0.2 – March 26, 2011

  - Renamed top-level constructor to `Client`.
  - Added top-level `serialize` and `deserialize` functions.
  - Added `autoMarshal` argument to `Client` for storing hierarchical data on
    nodes and relationship. Internally uses new `serialize` and `deserialize`
    functions.
  - Changed position of Client's `basePath` argument (now last).
  - Updated test.

## Version 0.0.1 – March 21, 2011

  - Initial release.


[Streamline.js]: https://github.com/Sage/streamlinejs
[@aseemk]: https://github.com/aseemk
[@gasi]: https://github.com/gasi
