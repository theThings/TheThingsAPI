# TheThingsAPI 1.0.0

This library wraps the [TheThings.IO](http://www.thethings.io) Internet of Things Cloud.

**To add this library to your project, add `#require "TheThingsAPI.class.nut:1.0.1"`` to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/thethingsapi/tree/v1.0.0).

## Class Usage

### Callbacks

All methods that make web requests to TheThings.IO (*activate*, *write*, and *read*) take an optional callback as a parameter. The callbacks require three parameters: err, resp, and data.

| parameter | notes |
| --------- | ----- |
| err       | `null` on success, or a string indicating the error |
| resp      | The [HTTP Response table](https://electricimp.com/docs/api/httprequest/sendasync/) from the request |
| data      | The decoded body of the request |

## Constructor: TheThingsAPI(*[thingToken]*)

Create a new thing passing it's existing token as an argument or leave it empty to activate it later using the *activate* function.

```squirrel
#require "TheThingsAPI.class.nut:1.0.0"

// Instantiate a thing with an existing token
thing <- TheThingsAPI("<-- EXISITING_TOKEN -->");
```

## Class Methods

### activate(*activationCode, [callback]*)
Activates a thing using an *Activation Code*.

```squirrel
// Create a thing object
thing <- TheThingsAPI();

// Activate a thing with a token from your Dev Console
thing.activate("<-- ACTIVATION_TOKEN -->", function(err, resp, data) {
    // If it failed - log an error message
    if (err) {
        server.error("Failed to activate Thing: " + err);
        return;
    }
    server.log("Success! Activated Thing!");
});
```

### addVar(*key, value, [metadata]*)
The addVar method allows you to add a key/value pair that will be sent to TheThings.IO the next time *write* is called. An optional third parameter - *metadata* - can be included to add additional metadata to the key/value pair. The *metadata* parameter should be a table with any of the following keys:

| key       | type    | description |
| --------- | ------- | ----------- |
| timestamp | integer | A unix timestamp (generated with [time()](https://electricimp.com/docs/squirrel/system/time)) or a datetime string (YYYYMMDDHHmmss) indicating when the sample was collected |
| geo       | table   | A table with "lat" and "long" keys describing the latitude and longitude where the sample was collected |

The *addVar* method returns a reference to `this`, allowing you to chain multiple calls to *addVar* together, or invoke *write* immediatly after *addVar*.

```squirrel
// Add a simple sample:
thing.addVar("foo", "bar");

// Add a sample with metadata:
thing.addVar("foo", "bar1", {
    "timestamp": time() - 3600,  // 1 hour ago
    "geo": {
        "lat": 41.4121132,
        "long": 2.2199454
    }
});

// Add two samples at once:
thing.addVar("foo", "bar").addVar("foo1": "bar1");

// Send all 4 samples to TheThings.IO
thing.write(function(err, resp, data) {
    if (err) {
        server.error(err);
        return;
    }
    server.log("Success!");
});
```

### write(*[callback]*)

Sends the information collected with *addVar* to TheThings.IO.

**See *addVar* for sample usage**

### read(*key, [filters, callback]*)

The *read* method returns one or more samples for the specified *key*. An optional second parameter - *filters* - can be passed to the read method to provide more information about the samples you are searching for. The filter table can contain any of the following keys:

| key       | type    | description |
| --------- | ------- | ----------- |
| limit     | integer | The maximum number of results to return (1-100) |
| startDate | integer | A unix timestamp (generated with [time()](https://electricimp.com/docs/squirrel/system/time)) or a datetime string (YYYYMMDDHHmmss) |
| endDate   | integer | A unix timestamp (generated with [time()](https://electricimp.com/docs/squirrel/system/time)) or a datetime string (YYYYMMDDHHmmss) |

**NOTE:** If a limit is not supplied, the read method will return the last sample for the specific key.

```squirrel
// Get the last sample collected for 'foo'
thing.read("foo", null, function(err, resp, data) {
    if (err) {
        server.error(err);
        return;
    }
    // Get the sample
    local result = data[0];
    // Do something with the sample
    server.log(result.datetime + ": " + result.value);
});

// Get the last 100 samples collected in the last 24 hours for 'foo'
local yesterday = time() - 86400; // 86400 seconds in a day
thing.read("foo", { "limit": 100, "startDate": yesterday }, function(err, resp, data) {
    if (err) {
        server.error(err);
        return;
    }

    foreach(sample in data) {
        server.log(sample.datetime + ": " + sample.value);
    }
});
```

### getToken()

Returns the Thing's *Thing Token*.

```squirrel
// Save the Thing's token:
local data = server.load();
data.token <- thing.getToken();
server.save(data);
```

# License

The TheThingsIO library is licensed under the [MIT License](https://github.com/electricimp/thethingsapi/tree/master/LICENSE).
