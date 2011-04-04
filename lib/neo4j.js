//////////////////////////////////////////////////////////////////////////////
//
//  Neo4j REST client for Node.js
//
//  Copyright 2011 Daniel Gasienica <daniel@gasienica.ch>
//  Copyright 2011 Sergio Haro <sergio.haro.jr@gmail.com>
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may
//  not use this file except in compliance with the License. You may obtain
//  a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations
//  under the License.
//
//////////////////////////////////////////////////////////////////////////////

var http = require('http');
var qs = require('querystring');


//----------------------------------------------------------------------------
//
//  Constructor
//
//----------------------------------------------------------------------------

var Client = exports.Client = module.exports.Client =
        function Client(host, port, autoMarshal, basePath) {
    this.host = host || 'localhost';
    this.port = port || 7474;
    this.autoMarshal = autoMarshal || false;
    this.basePath = basePath || '/db/data';
};

Client.prototype.getRoot = function (callback) {
    var options = {
        method: 'GET'
    };

    var handler = jsonBodyHandler(callback, this.autoMarshal);

    this.request('/', options, handler);
};

//----------------------------------------------------------------------------
//
//  Node methods
//
//----------------------------------------------------------------------------

Client.prototype.getNode = function (id, callback) {
    var options = {
        method: 'GET'
    };

    var handler = jsonBodyHandler(callback, this.autoMarshal);

    this.request('/node/' + id + '/properties', options, handler);
};

Client.prototype.getNodeDetails = function (id, callback) {
    var options = {
        method: 'GET'
    };

    var handler = jsonBodyHandler(callback, this.autoMarshal);

    this.request('/node/' + id, options, handler);
};

Client.prototype.getNodeProperty = function (id, property, callback) {
    var options = {
        method: 'GET'
    };

    var errorMessages = {
        404: 'Node not found'
    };

    this.request('/node/' + id + '/properties/' + encodeURIComponent(property),
        options, responseHandler(200, errorMessages, bodyParser, callback));
};

Client.prototype.getNodeURL = function (id) {
    var url = [
        'http://', this.host, ':', this.port, this.basePath, '/node/', id
    ].join('');
    return url;
};

Client.prototype.getIndexedNode = function (property, value, callback) {
    var options = {
        method: 'GET'
    };

    var path = [
        '/index/node/my_nodes/', encodeURIComponent(property), '/',
        encodeURIComponent(value)
    ].join('');

    var handler = jsonBodyHandler(callback, this.autoMarshal);

    this.request(path, options, handler);
};

Client.prototype.indexNode = function (id, property, value, callback) {
    var options = {
        method: 'POST',
        data: this.getNodeURL(id)
    };

    var errorMessages = {};
    var path = [
        '/index/node/my_nodes/', encodeURIComponent(property), '/',
        encodeURIComponent(value)
    ].join('');

    var parser = getHeaderParser('location');
    var handler = responseHandler(201, errorMessages, parser, callback);

    this.request(path, options, handler);
};

Client.prototype.deindexNode = function (id, property, value, callback) {
    var options = {
        method: 'DELETE',
        data: this.getNodeURL(id)
    };

    var errorMessages = {
        404 : 'Index entry not found',
    };

    var path = [
        '/index/node/my_nodes/', encodeURIComponent(property), '/',
        encodeURIComponent(value), '/', id
    ].join('');

    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.createNode = function (data, callback) {
    var options = {
        method: 'POST',
        data: data
    };

    var errorMessages = {
        400: 'Invalid data sent'
    };

    var parser = getHeaderParser('location');
    var handler = responseHandler(201, errorMessages, parser, callback);

    this.request('/node', options, handler);
};

Client.prototype.updateNode = function (id, data, callback) {
    var options = {
        method: 'PUT',
        data: data
    };

    var errorMessages = {
        404: 'Node not found',
        400: 'Invalid data sent'
    };

    var path = '/node/' + id + '/properties';
    var handler =  responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.updateNodeProperty = function (id, property, value, callback) {
    var options = {
        method: 'PUT',
        data: value
    };

    var errorMessages = {
        404: 'Node not found',
        400: 'Invalid data sent'
    };

    this.request('/node/' + id + '/properties/' + encodeURIComponent(property),
            options, responseHandler(204, errorMessages, nullParser, callback));
};

Client.prototype.deleteNode = function (id, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404: 'Node not found',
        409: 'Node could not be deleted (still has relationships?)'
    };

    var path = '/node/' + id;
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.deleteNodeProperties = function (id, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404 : 'Node or property not found'
    };

    var path = '/node/' + id + '/properties';
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.deleteNodeProperty = function (id, property, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404 : 'Node or property not found'
    };

    var path = '/node/' + id + '/properties/' + encodeURIComponent(property);
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};


//----------------------------------------------------------------------------
//
//  Relationship methods
//
//----------------------------------------------------------------------------

Client.prototype.createRelationship = function (fromId, toId, relationship, data, callback) {
    var options = {
        method: 'POST',
        data: {
            to: this.getNodeURL(toId),
            type: relationship,
            data: data
        }
    };

    var errorMessages = {
        400: 'Invalid data sent',
        404: '"to" node, or the node specified by the URI not found'
    };

    var path = '/node/' + fromId + '/relationships';
    var parser = getHeaderParser('location');
    var handler = responseHandler(201, errorMessages, parser, callback);

    this.request(path, options, handler);
};

Client.prototype.getRelationshipTypes = function (callback) {
    var options = {
        method: 'GET'
    };

    var path = '/relationships/types';
    var parser = getJSONParser(this.autoMarshal);
    var handler = responseHandler(200, errorMessages, parser, callback);

    this.request(path, options, handler);
};

// http://components.neo4j.org/neo4j-server/snapshot/rest.html#Get_relationships_on_node
Client.prototype.getRelationships = function (id, direction, types, callback) {
    var options = {
        method: 'GET'
    };

    var errorMessages = {
        404: 'Node not found'
    };

    var types = types || [];
    types.map(encodeURIComponent);

    var typesParameter = types.length > 0 ? '/' + types.join('&') : '';
    var path = '/node/' + id + '/relationships/' + direction + typesParameter;
    var parser = getJSONParser(this.autoMarshal);
    var handler = responseHandler(200, errorMessages, parser, callback);

    this.request(path, options, handler);
};

Client.prototype.getRelationshipsTo = function (id, types, callback) {
    return this.getRelationships(id, "in", types, callback);
};

Client.prototype.getRelationshipsFrom = function (id, types, callback) {
    return this.getRelationships(id, "out", types, callback);
};

Client.prototype.updateRelationshipProperties = function (id, data, callback) {
    var options = {
        method: 'POST',
        data: data
    };

    var errorMessages = {
        400: 'Invalid data sent',
        404: 'Relationship not found'
    };

    var path = '/relationship/' + id + '/properties';
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.updateRelationshipProperty = function (id, property, value, callback) {
    var options = {
        method: 'POST',
        data: value
    };

    var errorMessages = {
        400: 'Invalid data sent',
        404: 'Relationship not found'
    };

    var path = [
        '/relationship/', id, '/properties/', encodeURIComponent(property)
        ].join('');
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};


Client.prototype.getRelationshipProperties = function (id, callback) {
    var options = {
        method: 'GET'
    };

    var errorMessages = {
        204: 'No properties found',
        404: 'Relationship not found'
    };

    var path = '/relationship/' + id + '/properties';
    var parser = getJSONParser(this.autoMarshal);
    var handler = responseHandler(200, errorMessages, parser, callback);

    this.request(path, options, handler);
};

Client.prototype.getRelationshipProperty = function (id, property, callback) {
    var options = {
        method: 'GET'
    };

    var errorMessages = {
        404: 'Relationship or property not found'
    };

    var path = [
        '/relationship/', id, '/properties/', encodeURIComponent(property)
    ].join('');
    var handler = responseHandler(200, errorMessages, bodyParser, callback);

    this.request(path, options, handler);
};

Client.prototype.deleteRelationshipProperties = function (id, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404: 'Relationship not found'
    };

    var path = '/relationship/' + id + '/properties';
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.deleteRelationshipProperty = function (id, property, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404: 'Relationship or property not found'
    };

    var path = '/relationship/' + id + '/properties/' +
               encodeURIComponent(property);
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

Client.prototype.deleteRelationship = function (id, callback) {
    var options = {
        method: 'DELETE'
    };

    var errorMessages = {
        404: 'Relationship not found'
    };

    var path = '/relationship/' + id;
    var handler = responseHandler(204, errorMessages, nullParser, callback);

    this.request(path, options, handler);
};

//----------------------------------------------------------------------------
//
//  Utility methods
//
//----------------------------------------------------------------------------

Client.prototype.request = function (path, options, callback) {
    var path = path || '/';

    var options = options || {};
    var method = options.method || 'GET';
    var data = options.data || null;
    var params = options.params || null;

    // normalize path to begin with a slash
    if (path[0] !== '/') {
        path = '/' + path;
    }

    // add base path
    path = this.basePath + path;

    // attach query string parameters
    if (params) {
        var separator = '?';
        if (path.indexOf('?') !== -1) {
            separator = '&';
        }
        path += separator + qs.stringify(params);
    }

    var requestOptions = {
        host: this.host,
        port: this.port,
        method: method,
        path: path,
        headers: {
            'accept': 'application/json'
        }
    };

    if (data) {
        requestOptions.headers['content-type'] = 'application/json';
    }

    var request = http.request(requestOptions, function (res) {
        res.setEncoding('utf8');
        var body = '';
        res.on('data', function (chunk) {
            body += chunk;
        });
        res.on('end', function () {
            res.body = body
            callback(null, res);
        });
    });

    request.on('error', function (err) {
        callback(err, null);
    });

    if (data) {
        var output;
        if (this.autoMarshal) {
            output = exports.serialize(data)
        } else {
            output = JSON.stringify(data);
        }
        request.write(output);
    }

    request.end();
};

//----------------------------------------------------------------------------
//
//  Helpers
//
//----------------------------------------------------------------------------

function createErrorFromResponse(response) {
    var error = {
        statusCode: response.statusCode,
        headers: response.headers
    };
    return error;
}

// FIXME: export temporarily only
exports.getNodeId = function (url) {
    var NODE_REGEX = /(?:node\/(\d+))|(?:\/(\d+)\/?)$/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1] || match[2]) : null;
};

//----------------------------------------------------------------------------
//
//  Parsers
//
//----------------------------------------------------------------------------

function getJSONParser(autoMarshal) {
    var autoMarshal = !!autoMarshal;

    return function (res) {
        var body = res.body;
        if (autoMarshal) {
            data = exports.deserialize(body);
        } else {
            data = JSON.parse(body);
        }
    };
}

function getHeaderParser(header) {
    return function (res) {
        return res.headers[header];
    };
}

function bodyParser(res) {
    return res.body;
}

function nullParser(res) {
    return null;
}

function responseHandler(successCode, errorCodesMap, parser, callback) {
    return function(err, res) {
        var error = null;
        if(err) {
            callback(err, null);
        } else if (res.statusCode !== successCode) {
            error = createErrorFromResponse(res);
            var errMsg = errorCodesMap[res.statusCode];
            if(errMsg) {
                error.message = 'Node or property not found';
            }
            callback(error, null);
        } else {
            var data;
            try {
                data = parser(res);
            } catch(e) {
                error = new Error('Failed to parse data');
                error.innerError = e;
            }
            if (error) {
                callback(error, null);
            } else {
                callback(null, data);
            }
        }
    }
}

function jsonBodyHandler(callback, autoMarshal) {
    var errorMessages = {};
    var parser = getJSONParser(autoMarshal);
    return responseHandler(200, errorMessages, parser, callback);
}

//----------------------------------------------------------------------------
//
//  Serialization
//
//----------------------------------------------------------------------------

exports.serialize = function (o, separator) {
    var result = JSON.stringify(flatten(o, separator));
    return result;
};

exports.deserialize = function (o, separator) {
    var result = unflatten(JSON.parse(o), separator)
    return result;
};

function flatten(o, separator, result, prefix) {
    var separator = separator || '.';
    var result = result || {};
    var prefix = prefix || '';

    // only proceed if argument o is a complex object
    if (typeof o !== 'object') {
        return o;
    }

    for (var key in o) {
        if (o.hasOwnProperty(key)) {
            var value = o[key];
            if (typeof value !== 'object') {
                result[prefix + key] = value;
            } else {
                flatten(value, separator, result, key + separator);
            }
        }
    }

    return result;
}

function unflatten(o, separator, result) {
    var separator = separator || '.';
    var result = result || {};

    // only proceed if argument o is a complex object
    if (typeof o !== 'object') {
        return o;
    }

    for (var key in o) {
        if (o.hasOwnProperty(key)) {
            var value = o[key];
            var separatorIndex = key.indexOf(separator);
            if (separatorIndex === -1) {
                result[key] = value;
            } else {
                var keys = key.split(separator);
                var target = result;
                var numKeys = keys.length;
                for (var i = 0; i < numKeys - 1; i++) {
                    var currentKey = keys[i];
                    if (target[currentKey] === undefined) {
                        target[currentKey] = {};
                    }
                    target = target[currentKey];
                }
                var lastKey = keys[numKeys - 1];
                target[lastKey] = value;
            }
        }
    }

    return result;
}
