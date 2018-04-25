module vision.json.pointer;

struct JsonPointer
{
    import std.typecons : Nullable, nullable;
    import std.string : replace;
    import std.json;

    string[] path;

    @safe this(string path)
    {
        import std.algorithm : splitter, substitute, map;
        import std.range : drop;
        import std.array : array;
        import std.conv : to;

        if (path.length > 0 && path[0] != '/')
            throw new Exception("Incorrect syntax of JsonPointer: " ~ path);

        this.path = path.splitter('/').map!(s => s.replace("~1", "/")
                .replace("~0", "~").to!string).drop(1).array;
    }

    @safe static encodeComponent(string component) pure
    {
        return component.replace("~", "~0").replace("/", "~1");
    }

    Nullable!JSONValue evaluate(JSONValue root)
    {
        import std.conv : to, ConvException;
        import std.string : startsWith;
        import std.stdio;

        JSONValue cursor = root;

        foreach (component; path)
        {
            with (JSON_TYPE) switch (cursor.type)
            {
            case OBJECT:
                if (component !in cursor)
                    return Nullable!JSONValue();
                cursor = cursor[component];
                break;
            case ARRAY:
                try
                {
                    int index = component.to!int;
                    if (index < 0 || index >= cursor.array.length || component.startsWith("0"))
                        return Nullable!JSONValue();
                    cursor = cursor.array[index];
                }
                catch (ConvException e)
                {
                    return Nullable!JSONValue();
                }
                break;
            default:
                return Nullable!JSONValue();
            }
        }
        return nullable(cursor);
    }
}

unittest
{
    import std.json;

    // test exception for incorrect input value
    try
    {
        JsonPointer("a/b/c");
        assert(false, "Incorrect pointer syntax must call exception");
    }
    catch (Exception e)
    {
    }

    // tests for path parsing
    assert(JsonPointer("").path == []);
    assert(JsonPointer("/").path == [""]);
    assert(JsonPointer("/a/b/c").path == ["a", "b", "c"]);
    assert(JsonPointer("/a~0a/b~1b/c~01c/d~10d").path == ["a~a", "b/b", "c~1c", "d/0d"]);
    assert(JsonPointer("/Киррилица, Ё, ЯФЫЖЭЗЮЙ/إنه نحن العرب")
            .path == ["Киррилица, Ё, ЯФЫЖЭЗЮЙ", "إنه نحن العرب"]);

    // test encodeComponent
    assert(JsonPointer.encodeComponent("a/b~c") == "a~1b~0c");

    string s = `{ "language": "D", "rating": 3.5, "code": "42", "o": {"p1": 5, "p2": 6}, "a": [1,2,3,4,5] }`;
    JSONValue j = parseJSON(s);

    // tests for successful requests
    assert(JsonPointer("/language").evaluate(j).str == "D");
    assert(JsonPointer("/rating").evaluate(j).floating == 3.5);
    assert(JsonPointer("/o/p1").evaluate(j).integer == 5);
    assert(JsonPointer("/a/3").evaluate(j).integer == 4);

    // tests for failing requests
    assert(JsonPointer("/nonexistent").evaluate(j).isNull);
    assert(JsonPointer("/a/b0").evaluate(j).isNull);
    assert(JsonPointer("/a/00").evaluate(j).isNull);
    assert(JsonPointer("/a/20").evaluate(j).isNull);
    assert(JsonPointer("/a/p3").evaluate(j).isNull);
    assert(JsonPointer("/rating/0").evaluate(j).isNull);
}
