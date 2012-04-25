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
