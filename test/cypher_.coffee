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

# test: can query a single user
results = db.query _, "start n=(#{user0.id}) return n"
assert.ok results instanceof Array
assert.equal results.length, 1
assert.equal typeof results[0], 'object'
assert.ok results[0].hasOwnProperty 'n'
assert.equal typeof results[0]['n'], 'object'
assert.equal results[0]['n'].data.name, user0.name

# test: can query multiple users
results = db.query _, "start n=(#{user0.id},#{user1.id},#{user2.id}) return n"
assert.equal results.length, 3
assert.equal results[0]['n'].data.name, user0.name
assert.equal results[1]['n'].data.name, user1.name
assert.equal results[2]['n'].data.name, user2.name

# give some confidence that these tests actually passed ;)
console.log 'passed the shit out of the cypher tests'
