[![Build Status](https://travis-ci.org/crimaniak/json-pointer.svg)](https://travis-ci.org/crimaniak/json-pointer)
[![codecov](https://codecov.io/gh/crimaniak/json-pointer/branch/master/graph/badge.svg)](https://codecov.io/gh/crimaniak/json-pointer)
[![license](https://img.shields.io/github/license/crimaniak/json-pointer.svg)](https://github.com/crimaniak/json-pointer/blob/master/LICENSE)

# JavaScript Object Notation (JSON) Pointer

This is implementation of [rfc6901](https://tools.ietf.org/html/rfc6901).

JsonPointer for Json, like XPath for XML, used to locate part of document using format string.

library functionality: 

* JsonPointer path parsing and verification
* element search in a document
* JsonPointer path component encoding

 Json document format accepted: [JSONValue](https://dlang.org/phobos/std_json.html#.JSONValue)

### Interface
```D
    struct JsonPointer
    {
    
    	/** 
    	 * Constructor. 
    	 * @throws Exception if error in path
    	 */
    	@safe this(string path);

       /// encode path component, quoting '~' and '/' symbols according to rfc6901
    	@safe static encodeComponent(string component) pure;
    	
    	// find element in given document according to path
    	Nullable!JSONValue evaluate(JSONValue root);
    	
    }
```
### Usage examples

```D
    import vision.json.pointer;
    import std.json;
    
    string s = `{ "language": "D", "rating": 3.5, "code": "42", "o": {"p1": 5, "p2": 6}, "a": [1,2,3,4,5] }`;
    JSONValue j = parseJSON(s);

    // tests for successful requests
    assert(JsonPointer("/language").evaluate(j).str == "D");
    assert(JsonPointer("/rating").evaluate(j).floating == 3.5);
    assert(JsonPointer("/o/p1").evaluate(j).integer == 5);
    assert(JsonPointer("/a/3").evaluate(j).integer == 4);
    
    // test encodeComponent
    assert(JsonPointer.encodeComponent("a/b~c") == "a~1b~0c");
    
```
