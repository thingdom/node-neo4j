
#
# Parses and returns the top-level native Neo4j ID out of the given Neo4j URL,
# or null if no top-level ID could be matched.
#
# Works with any type of object exposed by Neo4j at the root of the service API,
# e.g. nodes, relationships, even transactions.
#
@parseId = (url) ->
    match = url.match /// /db/data/\w+/(\d+)($|/) ///
    return null if not match
    return parseInt match[1], 10
