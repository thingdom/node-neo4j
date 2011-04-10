# Changelog: Neo4j REST client for Node.js

## Version 0.1.0

  - Changed name from _Neo4j REST client for Node.js_ to _Node driver for Neo4j_.
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
