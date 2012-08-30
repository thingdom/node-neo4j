# will be used for testing gremlin script executions
# as well as validating the return results are as expected

assert = require('assert')
neo4j = require('..')

db = new neo4j.GraphDatabase 'http://localhost:7474'

# convenience wrapper
createNode = (name) ->
	node = db.createNode {name}
	node.name = name
	node.toString = -> name
	node

#create some nodes
users = for i in [0..6]
	createNode "gremlinTest#{i}"

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

# test: can query a single user
results = db.execute """
	g.v(#{user0.id})
""", {}, _

assert.ok typeof results, 'object'
assert.ok typeof results.data.name, 'string' # dislike this because it will throw for the wrong reasons possibly 
assert.equal results.data.name, user0.name

console.log "Single Result Gremlin Test Passed."