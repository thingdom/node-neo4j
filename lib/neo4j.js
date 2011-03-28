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

Client.prototype.createNode = function (data, callback) {
    var options = {
        method: 'POST',
        data: data
    };

    this.request('/node', options,
        function(err, res) {
            var error;
            if (err) {
                callback(err, null);
            } else if (res.statusCode !== 201) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 400:
                        error.message = 'Invalid data sent.';
                        break;
                }
                callback(error, null);
            } else {
                var location = res.headers['location'];
                callback(null, location);
            }
        }
    );
};

Client.prototype.updateNode = function (id, data, callback) {
    var options = {
        method: 'PUT',
        data: data
    };
    this.request('/node/' + id + '/properties', options,
        function(err, res) {
            var error;
            if (err) {
                callback(err);
            } else if (res.statusCode !== 204) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 400:
                        error.message = 'Invalid data sent.';
                        break;
                    case 404:
                        error.message = 'Node not found';
                        break;
                    default:
                        break;
                }
                callback(error);
            } else {
                callback(null);
            }
        }
    );
};

Client.prototype.deleteNode = function (id, callback) {
    var options = {
        method: 'DELETE'
    };
    this.request('/node/' + id, options,
        function(err, res) {
            var error;
            if (err) {
                callback(err);
            } else if (res.statusCode !== 204) {
                error = createErrorFromResponse(res);
                switch(res.statusCode) {
                    case 404:
                        error.message = 'Node not found';
                        break;
                    case 409:
                        error.message = 'Node could not be deleted (still has relationships?)';
                        break;
                    default:
                        break;
                }
                callback(error);
            } else {
                callback(null);
            }
        }
    );
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

function jsonBodyHandler(callback, autoMarshal) {
    var autoMarshal = autoMarshal || false;
    return function(err, res) {
        var error = null;
        if (err) {
            callback(err, null);
        } else if (res.statusCode !== 200) {
            error = createErrorFromResponse(res);
            callback(error, null);
        } else {
            var data;
            try {
                if (autoMarshal) {
                    data = exports.deserialize(res.body);
                } else {
                    data = JSON.parse(res.body);
                }
            } catch(e) {
                error = new Error('Failed to parse JSON.');
                error.innerError = e;
            }
            if (error) {
                callback(error, null);
            } else {
                callback(null, data);
            }
        }
    };
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
