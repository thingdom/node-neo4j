# this file is in streamline syntax!
# https://github.com/Sage/streamlinejs

neo4j = require '..'
db = new neo4j.GraphDatabase 'http://localhost:7474'

NUM_NODES = 100000

console.log "Constructing #{NUM_NODES} nodes..."
beginTime = Date.now()

for i in [0...NUM_NODES]
    db.createNode {}

timeDelta = Date.now() - beginTime
console.log "Took #{timeDelta / 1000} secs."
