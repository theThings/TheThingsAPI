// Copyright (c) 2015 TheThings.iO
// This file is licensed under the MIT License
// http://opensource.org/licenses/MIT

class TheThingsAPI {
    static version = [1,0,1];

    static URLROOT = "https://api.devices.thethings.io/v2/things/";

    static HEADERS_WRITE = { "Accept": "application/json", "Content-Type": "application/json" };
    static HEADERS_READ = { "Accept": "application/json" };
    static HEADERS_ACT = { "Accept": "application/json", "Content-Type": "application/json" };

    _token = null;      // Thing Token
    _urlWrite = null;   // URL we make write requests to
    _urlRead = null;    // URL we make read requests to
    _urlAct = null;     // URL we make activation requests to

    _data = null;       // Cached data waiting to be sent

    // Create a new thing passing it's existing token as an argument
    // or leave it empty to activate it later using the "activate" function.
    constructor(token = null) {
        _initData(token);
    }

    // Activate a new thing. This is only necessary if you don't have
    // it's token. An activation code is required.
    function activate(activationCode, cb = null) {
        // Create the request
        local data = http.jsonencode({ "activationCode": activationCode });
        local request = http.post(_urlAct, HEADERS_ACT, data);

        // Wrap the callback to set the token and initalize data
        request.sendasync(_activateCallbackFactory(cb));
    }

    // To write a variable into the theThings.iO cloud, call this function with
    // the value to write. This function can be called any times to add more
    // variables to be sent. Finally, call the "write" function to actually write
    // the values.
    //
    // key: string
    // value: number or string
    // metadata: optional table with additional information:
    //           timestamp:  a unix timestamp of when the measurment was taken, or
    //                       a datetime string with the format YYYYMMDDHHmmss
    //           geo:        a table with "lat" and "long" keys indicating the
    //                       geographic location the measurment was taken
    function addVar(key, value, metadata = null) {
        if(!_data) throw "Thing not initialized";

        // Set the datapoint
        local dataPoint = { "key": key, "value": value };

        // Set extra metadata if provided
        if ("timestamp" in metadata) {
            if (typeof metadata.timestamp == "string") {
                // If they passed in a string, assume it's a pre-formated string
                dataPoint.datetime <- metadata.timestamp;
            } else {
                // Otherwise, convert it to a string
                dataPoint.datetime <- _formatDateTime(metadata.timestamp);
            }
        }

        if ("geo" in metadata && "lat" in metadata.geo && "long" in metadata.geo) {
            dataPoint.geo <- { "lat": metadata.geo.lat, "long": metadata.geo.long };
        }

        // Push the datapoint into our array
        _data.values.push(dataPoint);

        return this;
    }

    // Sends _data
    function write(cb = null) {
        local data = http.jsonencode(_data);
	// Reset buffered data
         _data = { values = [] };

        // Send the request and proces the response
        local request = http.post(_urlWrite, HEADERS_WRITE, data);
        request.sendasync(_writeCallbackFactory(cb));
    }

    // Read a variable from the theThings.iO. If only the argument
    // "key" is specified, the last value will be returned. This function will
    // return "limit" number of values of the variable inside an array.
    //
    // key:     name of the variable
    // filters  a table containing filter parameters:
    //              limit       number of results to return
    //              startDate   a unix timestamp, or
    //                          a datetime string with the format YYYYMMDDHHmmss
    //              endDate     a unix timestamp, or
    //                          a datetime string with the format YYYYMMDDHHmmss
    function read(key, filters = null, cb = null) {
        filters = filters ? filters : {};   // make sure options is a table

        local getUrl = _urlRead + key + "/";

        // Create the parameter table
        local params = {};
        if ("limit" in filters) params.limit <- filters.limit;

        if ("startDate" in filters) {
            if (typeof filters.startDate == "string") {
                // If they passed in a string, assume it's a pre-formated string
                params.startDate <- filters.startDate;
            } else {
                // Otherwise, convert it to a string
                params.startDate <- _formatDateTime(filters.startDate);
            }
        }

        if ("endDate" in filters) {
            if (typeof filters.endDate == "string") {
                // If they passed in a string, assume it's a pre-formated string
                params.endDate <- filters.endDate;
            } else {
                // Otherwise, convert it to a string
                params.endDate <- _formatDateTime(filters.endDate);
            }
        }

        // encode the parameters and add it to the getUrl
        if (params.len() > 0) getUrl += "?" + http.urlencode(params);

        local request = http.get(getUrl, HEADERS_READ);
        request.sendasync(_callbackFactory(cb));
    }

    // Returns the thing's token
    function getToken() {
        return _token;
    }

    //-------------------- PRIVATE METHODS --------------------//

    // Formats a datetime string for TheThingsIO
    //
    // params: ts   a timestamp generated by time()
    // returns:     a string with the following format: YYYYMMDDhhmmss
    function _formatDateTime(ts) {
        local d = date(ts);

        return format("%04i%02i%02i%02i%02i%02i", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
    }

    // Wraps a user callback (err, resp, data) and sets _token on success
    function _activateCallbackFactory(cb) {
        return _callbackFactory(function(err, resp, data) {
            // Set token on success
            if (err == null) _initData(data.thingToken);

            // Invoke the user callback
            if (cb) cb(err, resp, data);
        }.bindenv(this));
    }

    // Wraps a user callback (err, resp, data) and clears _data on success
    function _writeCallbackFactory(cb) {
        return _callbackFactory(function(err, resp, data) {
            // Invoke the user callback
            if (cb) cb(err, resp, data);
        }.bindenv(this));
    }

    // Creates an http request callback that wraps a user callback (err, resp, data)
    function _callbackFactory(cb) {
        return function(resp) {
            // If we didn't get a 2xx status code, there was an error..
            if (resp.statuscode < 200 || resp.statuscode >= 300) {
                try {
                    // If we failed to activate
                    local data = http.jsondecode(resp.body);
                    if (cb) imp.wakeup(0, function() { cb(data.message, resp, null); });
                    return;
                } catch (err) {
                    // If we got back bad JSON
                    if (cb) imp.wakeup(0, function() { cb(err, resp, null); });
                    return;
                }
            }
            try {
                // If we activated the object:
                local data = http.jsondecode(resp.body);
                if (cb) imp.wakeup(0, function() { cb(null, resp, data); });
            } catch(err) {
                // If we got back bad JSON
                if (cb) imp.wakeup(0, function() { cb(err, resp, null) });
                return;
            }
        }.bindenv(this);
    }

    // Sets the token, builds URLs, and initializes the _data object
    function _initData(token) {
        _token = token;
        _urlWrite = URLROOT + _token;
        _urlRead = URLROOT + _token + "/resources/";
        _urlAct = URLROOT;

        if (token != null) _data = { values = [] };
    }
}
