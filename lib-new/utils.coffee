
#
# Parses and returns the top-level native Neo4j ID out of the given Neo4j URL,
# or null if no top-level ID could be matched.
#
# Works with any type of object exposed by Neo4j at the root of the service API,
# e.g. nodes, relationships, even transactions.
#
@parseId = (url) ->
    # NOTE: Neo4j 2.1.7 shipped a bug with hypermedia links returned from the
    # transactional endpoint, so we have to account for that:
    # https://github.com/neo4j/neo4j/issues/4076
    match = url.match /// (?:commit|/)db/data/\w+/(\d+)($|/) ///
    return null if not match
    return parseInt match[1], 10
