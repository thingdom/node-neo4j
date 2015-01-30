
#
# Parses and returns the native Neo4j ID out of the given Neo4j URL,
# or null if no ID could be matched.
#
@parseId = (url) ->
    match = url.match /// /db/data/(node|relationship)/(\d+)$ ///
    return null if not match
    return parseInt match[2], 10
