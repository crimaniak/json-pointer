module vision.json.pointer;

struct JsonPointer
{
    import std.conv : to;
    import std.typecons : Nullable;
    import std.string : replace;
    import std.json;

    string[] path;

    /** 
   	 * Constructor from string
   	 * @throws Exception if error in path
   	 */
    @safe this(const string path)
    {
        import std.algorithm : splitter, map;
        import std.range : drop;
        import std.array : array;

        if (path.length > 0 && path[0] != '/')
            throw new Exception("Incorrect syntax of JsonPointer: " ~ path);

        this.path = path.splitter('/').map!(s => s.replace("~1", "/")
                .replace("~0", "~").to!string).drop(1).array;
    }

    /** 
   	 * Constructor from array of components 
   	 * @throws Exception if error in path
   	 */
    @safe this(const string[] path)
    {
        this.path = path.dup;
    }

    /// encode path component, quoting '~' and '/' symbols according to rfc6901
    @safe static encodeComponent(string component) pure
    {
        return component.replace("~", "~0").replace("/", "~1");
    }

    /// find element in given document according to path
    Nullable!(JSONValue*) evaluate(ref JSONValue root) const
    {
        return evaluate(&root);
    }

    /// find element in given document according to path
    Nullable!(JSONValue*) evaluate(JSONValue* root) const
    {
        import std.conv : to, ConvException;
        import std.string : startsWith;
        import std.stdio;

        auto cursor = root;

        foreach (component; path)
        {
            with (JSON_TYPE) switch (cursor.type)
            {
            case OBJECT:
                if (component !in *cursor)
                    break;
                cursor = &((*cursor)[component]);
                continue;
            case ARRAY:
                try
                {
                    int index = component.to!int;
                    if (index < 0 || index >= cursor.array.length || (component.startsWith("0") && component.length>1))
                        break;
                    cursor = &(cursor.array[index]);
                    continue;
                }
                catch (ConvException e)
                {
                    break;
                }
            default:
                break;
            }
            return Nullable!(JSONValue*)();
        }
        return Nullable!(JSONValue*)(cursor);
    }

	/// Return true for empty path
    @property bool isRoot() const @safe
    {
        return path.length == 0;
    }

	/// Get path for parent element
    @property Nullable!JsonPointer parent() const @safe
    {
        return isRoot ? Nullable!JsonPointer() : Nullable!JsonPointer(JsonPointer(path[0 .. $ - 1]));
    }

	/// Get last component of path
    @property string lastComponent() const @safe
    {
        return path[$ - 1];
    }

	/// Convert path to string
    string toString() const @safe
    {
        import std.algorithm : map, joiner;
        import std.range : chain;

        return path.map!(part => chain("/"c, encodeComponent(part))).joiner("").to!string;
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

    assert(JsonPointer("/a/b/c").parent.path == ["a", "b"]);
    assert(JsonPointer("/a/b/c").lastComponent == "c");

    // isRoot()
    assert(JsonPointer("").isRoot);
    assert(!JsonPointer("/").isRoot);
    assert(JsonPointer("").parent.isNull);
    assert(JsonPointer("/").parent.isRoot);

    // toString tests
    foreach (p; ["/a/b/c", "/a~0a/b~1b/c~01c/d~10d"])
        assert(JsonPointer(p).toString == p);

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
    
    // fix #6
    JSONValue arr = parseJSON("[1,2,3,4,5]");
    assert(!JsonPointer("/0").evaluate(arr).isNull);
    
}

