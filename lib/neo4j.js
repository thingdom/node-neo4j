//////////////////////////////////////////////////////////////////////////////
//
//  Neo4j REST client for Node.js
//
//  Copyright 2011 Daniel Gasienica <daniel@gasienica.ch>
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
    this.request('/', options, jsonBodyHandler(callback, this.autoMarshal));
};

Client.prototype.getNode = function (id, callback) {
    var options = {
        method: 'GET'
    };
    this.request('/node/' + id + '/properties', options,
        jsonBodyHandler(callback, this.autoMarshal));
};

Client.prototype.getNodeDetails = function (id, callback) {
    var options = {
        method: 'GET'
    };
    this.request('/node/' + id, options,
        jsonBodyHandler(callback, this.autoMarshal));
};

Client.prototype.getNodeProperty = function (id, property, callback) {
    var options = {
        method: 'GET'
    };
    
    var errMsgs = {
        404 : 'Node not found'
    };
    
    this.request('/node/' + id + '/properties/' + encodeURIComponent(property), options,
        responseHandler(200, errMsgs, bodyParser, callback) );
};

Client.prototype.getNodeURL = function (id) {
    var url = ['http://', this.host, ':', this.port, this.basePath,
               '/node/', id].join('');
    return url;
};

Client.prototype.getIndexedNode = function (property, value, callback) {
    var options = {
        method: 'GET'
    };

    var path = ['/index/node/my_nodes/', encodeURIComponent(property),
                '/', encodeURIComponent(value)].join('');

    this.request(path, options, jsonBodyHandler(callback, this.autoMarshal));
};

Client.prototype.indexNode = function (id, property, value, callback) {
    var options = {
        method: 'POST',
        data: this.getNodeURL(id)
    };

    var path = ['/index/node/my_nodes/', encodeURIComponent(property),
                '/', encodeURIComponent(value)].join('');

    this.request(path, options,
        responseHandler(201, {}, getHeaderParser('location'), callback) );
};

Client.prototype.deindexNode = function (id, property, value, callback) {
    var options = {
        method: 'DELETE',
        data: this.getNodeURL(id)
    };
    
    var errMsgs = {
        404 : 'Index entry not found',
    };
    
    var path = ['/index/node/my_nodes/', encodeURIComponent(property),
                '/', encodeURIComponent(value), '/', id].join('');

    this.request(path, options,
        responseHandler(204, errMsgs, noOpParser, callback) );
};

Client.prototype.createNode = function (data, callback) {
    var options = {
        method: 'POST',
        data: data
    };

    var errMsgs = {
        400: 'Invalid data sent.'
    };
    
    this.request('/node', options,
        responseHandler(201, errMsgs, getHeaderParser('location'), callback) );
};

Client.prototype.updateNode = function (id, data, callback) {
    var options = {
        method: 'PUT',
        data: data
    };
    
    var errMsgs = {
        404 : 'Node not found',
        400: 'Invalid data sent.'
    };
    
    this.request('/node/' + id + '/properties', options,
        responseHandler(204, errMsgs, noOpParser, callback) );
};

Client.prototype.updateNodeProperty = function (id, property, value, callback) {
    var options = {
        method: 'PUT',
        data: value
    };
    
    var errMsgs = {
        404 : 'Node not found',
        400: 'Invalid data sent.'
    };
    
    this.request('/node/' + id + '/properties/' + encodeURIComponent(property), options,
        responseHandler(204, errMsgs, noOpParser, callback) );
};

Client.prototype.deleteNode = function (id, callback) {
    var options = {
        method: 'DELETE'
    };
    
    var errMsgs = {
        404 : 'Node not found',
        409: 'Node could not be deleted (still has relationships?)'
    };
    
    this.request('/node/' + id, options,
        responseHandler(204, errMsgs, noOpParser, callback) );
};

Client.prototype.deleteNodeProperties = function (id, callback) {
    var options = {
        method: 'DELETE'
    };
    
    var errMsgs = {
        404 : 'Node or property not found'
    };
    
    this.request('/node/' + id + '/properties', options,
        responseHandler(204, errMsgs, noOpParser, callback));
};

Client.prototype.deleteNodeProperty = function (id, property, callback) {
    var options = {
        method: 'DELETE'
    };
    
    var errMsgs = {
        404 : 'Node or property not found'
    };
    
    this.request('/node/' + id + '/properties/' + encodeURIComponent(property), options,
        responseHandler(204, errMsgs, noOpParser, callback));
};

Client.prototype.request = function (path, options, callback) {
    var path = path || '/';

    var options = options || {};
    var method = options.method || 'GET';
    var data = options.data || null;
    var params = options.params || null;

    // normalize path to begin with a slash
    if (path.charAt(0) !== '/') {
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
            'Accept': 'application/json'
        }
    };

    if (data) {
        requestOptions.headers['Content-Type'] = 'application/json';
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
        callback(error, null);
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

// helpers

function createErrorFromResponse(response) {
    var error = {
        statusCode: response.statusCode,
        headers: response.headers
    };
    return error;
}

function getJsonParser(autoMarshal) {
    var autoMarshal = autoMarshal || false;
    return function(res) {
        if (autoMarshal) {
            data = exports.deserialize(res.body);
        } else {
            data = JSON.parse(res.body);
        }
    }
}

function getHeaderParser(headerProperty) {
    return function(res) {
        return res.headers[headerProperty];
    }
}

function bodyParser(res) {
    return res.body;
}

function noOpParser(res) {
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
    return responseHandler(200, {}, getJsonParser(autoMarshal), callback);
}

// TODO: export temporarily only
exports.getNodeId = function (url) {
    var NODE_REGEX = /(?:node\/(\d+))|(?:\/(\d+)\/?)$/g;
    var match = NODE_REGEX.exec(url);
    return match ? parseInt(match[1] || match[2]) : null;
};

// serialization / deserialization

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
