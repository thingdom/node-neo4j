# we'll be creating a somewhat complex graph and testing that cypher queries
# on it return expected results.

assert = require 'assert'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# convenience wrapper:
createNode = (name) ->
    node = db.createNode {name}
    node.name = name
    node.toString = -> name
    node

# FOLLOWERS

# users: user0 thru user9
users = for i in [0..9]
    createNode "user#{i}"

# save in parallel
futures = (user.save() for user in users)
future _ for future in futures

# convenience aliases
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]
user4 = users[4]
user5 = users[5]
user6 = users[6]
user7 = users[7]
user8 = users[8]
user9 = users[9]

# test: can query a single user
results = db.query """
    START n=node(#{user0.id})
    RETURN n
""", _
assert.ok results instanceof Array
assert.equal results.length, 1
assert.equal typeof results[0], 'object'
assert.ok results[0].hasOwnProperty 'n'
assert.equal typeof results[0]['n'], 'object'
assert.equal results[0]['n'].data.name, user0.name

# test: can query multiple users
results = db.query """
    START n=node(#{user0.id},#{user1.id},#{user2.id})
    RETURN n
""", _
assert.equal results.length, 3
assert.equal results[0]['n'].data.name, user0.name
assert.equal results[1]['n'].data.name, user1.name
assert.equal results[2]['n'].data.name, user2.name

# have user0 follow user1, user2 and user3
# have user1 follow user2, user3 and user4
# ...
# have user8 follow user9, user0 and user1
# have user9 follow user0, user1 and user2
createFollowRelationships = (i, _) ->
    user = users[i]
    i1 = (i + 1) % users.length
    i2 = (i + 2) % users.length
    i3 = (i + 3) % users.length
    # create three relationships in parallel
    # WARNING: don't use a variable named futures here!
    # coffeescript variable shadowing will kick in unexpectedly. =(
    f1 = user.createRelationshipTo users[i1], 'follows', {}
    f2 = user.createRelationshipTo users[i2], 'follows', {}
    f3 = user.createRelationshipTo users[i3], 'follows', {}
    f1 _
    f2 _
    f3 _

# create follow relationships for each user in parallel
futures = (createFollowRelationships(i) for user, i in users)
future _ for future in futures

# test: can query relationships and return multiple values
results = db.query """
    START n=node(#{user6.id})
    MATCH (n) -[r:follows]-> (m)
    RETURN r, m.name
""", _
assert.equal results.length, 3
assert.ok typeof results[0]['r'], 'object'
assert.ok typeof results[0]['m.name'], 'string'
assert.equal results[0]['r'].type, 'follows'
assert.equal results[0]['m.name'], user7.name
assert.equal results[1]['m.name'], user8.name
assert.equal results[2]['m.name'], user9.name

# test: sending query parameters instead of literals
results = db.query '''
    START n=node({userId})
    MATCH (n) -[r:follows]-> (m)
    RETURN r, m.name
''', {userId: user3.id}, _
assert.equal results.length, 3
assert.ok typeof results[0]['r'], 'object'
assert.ok typeof results[0]['m.name'], 'string'
assert.equal results[0]['r'].type, 'follows'
assert.equal results[0]['m.name'], user4.name
assert.equal results[1]['m.name'], user5.name
assert.equal results[2]['m.name'], user6.name

# test: can return nodes in an array
results = db.query """
    START n=node(#{user0.id},#{user1.id},#{user2.id})
    RETURN collect(n)
""", _
assert.equal results.length, 1
assert.ok results[0]['collect(n)'] instanceof Array
assert.ok typeof results[0]['collect(n)'][0] 'object'
assert.equal results[0]['collect(n)'][0].id, user0.id
assert.equal results[0]['collect(n)'][0].data.name, user0.name

# test: can return paths
results = db.query """
    START from=node({fromId}), to=node({toId})
    MATCH path=shortestPath(from -[:follows*..3]-> to)
    RETURN path
""", {fromId: user0.id, toId: user6.id}, _
assert.equal results.length, 1
assert.ok typeof results[0]['path'], 'object'
assert.ok typeof results[0]['path'].start, 'object'
assert.ok typeof results[0]['path'].end, 'object'
assert.ok results[0]['path'].nodes instanceof Array
assert.ok results[0]['path'].relationships instanceof Array
assert.equal results[0]['path'].length, 2
assert.equal results[0]['path'].start.id, user0.id
assert.equal results[0]['path'].end.id, user6.id
assert.equal results[0]['path'].nodes.length, 3
assert.equal results[0]['path'].nodes[1].id, user3.id
assert.equal results[0]['path'].relationships.length, 2

# give some confidence that these tests actually passed ;)
console.log 'passed cypher tests'
