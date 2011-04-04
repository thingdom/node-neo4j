var assert = require('assert');
var neo4j = require('../lib/neo4j');
var sys = require('sys');

// database
var DB_HOST = 'localhost';
var DB_PORT = 7474;
var db = new neo4j.Client(DB_HOST, DB_PORT, true);

// data
var data = {
    name: 'Daniel Gasienica',
    magicNumber: 42,
    lovesIceCream: true
};
var newData = {
    name: 'Daniel Gasienica',
    father: {
        firstName: 'Jan',
        lastName: 'Gasienica'
    },
    tired: false
};

// test create, get, update, delete
db.createNode(data, function(err, res) {
    if (err) {
        console.log('Error: Failed to create node');
    } else {
        var id = getNodeId(res);
        db.getNode(id, function (err, res) {
            if (err) {
                console.log('Error: Failed to get node %d (%s)',
                    id, JSON.stringify(err));
            } else {
                assert.deepEqual(res, data,
                        'Retrieved data does not match original data.');
                db.updateNode(id, newData, function (err, res) {
                    assert.ifError(err);
                    db.getNode(id, function (err, res) {
                        assert.deepEqual(res, newData,
                            'Retrieved data does not match updated data.');
                        db.deleteNode(id, function (err) {
                            if (err) {
                                console.log('Error: Failed to delete node %d (%s)',
                                    id, JSON.stringify(err));
                            } else {
                                db.getNode(id, function (err, res) {
                                    assert.strictEqual(res, null, 'Result not null.');
                                    assert.strictEqual(err.statusCode, 404,
                                            'Found node even though it was deleted.');
                                })
                            }
                        });
                    });
                });
            }
        });
    }
});

// test serialization / deserialization
var transform = function (o) {
    return neo4j.deserialize(neo4j.serialize(o));
}

assert.deepEqual(transform(data), data);
assert.deepEqual(transform(newData), newData);

var o;

// numbers
o = 1;
assert.strictEqual(transform(o), o);

// strings
o = "gasi";
assert.strictEqual(transform(o), o);

// booleans
o = true;
assert.strictEqual(transform(o), o);

// Arrays are not supported
o = [true, false, true];
assert.throws(transform(o));

// Using illegal separator '.' in object key should fail
o = {"this.that": "shouldn't work"};
assert.notDeepEqual(transform(o), o);

// prune database
// for (var i = 0; i < 1000; i++) {
//     db.deleteNode(i, function (err) {});
// }


// helper
function print(error, result) {
    console.log(error ? error : (result ? result : ''));
};

function getNodeId(url) {
    var NODE_REGEX = /node\/(\d+)/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1]) : null;
}
