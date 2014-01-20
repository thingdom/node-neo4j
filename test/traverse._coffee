{expect} = require 'chai'
flows = require 'streamline/lib/util/flows'
neo4j = require '..'

db = new neo4j.GraphDatabase 'http://localhost:7474'

# seed nodes into graph
users = for i in [0..6]
  db.createNode
    name: "traversalTest#{i}"

# node shortcut references
user0 = users[0]
user1 = users[1]
user2 = users[2]
user3 = users[3]
user4 = users[4]
user5 = users[5]
user6 = users[6]

@traverse = 

  '(pre-req) save nodes': (_) ->
    flows.collect _,
      for user in users
        user.save not _

  '(pre-req) create relationships': (_) ->
    createFollowRelationships = (i, _) ->
      user = users[i]
      i1 = (i + 1) % users.length
      i2 = (i + 2) % users.length
      i3 = (i + 3) % users.length
      flows.collect _, [
        user.createRelationshipTo users[i1], 'traverse_follows', {}, not _
        user.createRelationshipTo users[i2], 'traverse_follows', {}, not _
        user.createRelationshipTo users[i3], 'traverse_follows', {}, not _
      ]

    flows.collect _,
      for user, i in users
        createFollowRelationships i, not _

  'traverse connected nodes': (_) ->
    nodes = user0.traverse 'node', {
      order: 'breadth_first',
      return_filter: {
        body: """position.endNode().getProperty('name').contains('t')""",
        language: 'javascript'
      },
      prune_evaluator: {
        body: 'none',
        language: 'builtin'
      },
      uniqueness: 'node_global',
      relationships: [{
        direction: 'all',
        type: 'traverse_follows'
      }],
      max_depth: 3
    }, _

    expect(nodes).to.exist
    expect(nodes).to.be.an 'array'
    expect(nodes).to.have.length 7
    expect(nodes[0]).to.exist;

    nodes.forEach (node) =>
      expect(node.data).to.be.an 'object'
      expect(node.data.name).to.contain 't'

for name, test of @traverse
  do (name, test) =>
    @traverse[name] = (_) ->
      test _
