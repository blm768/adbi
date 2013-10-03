module adbi.traits;

public import std.traits;
public import std.typetuple;

template TemplateMap(alias Mapper, Tuple ...) {
	static if(Tuple.length == 0) {
		alias TypeTuple!() TemplateMap;
	} else {
		alias TypeTuple!(Mapper!(Tuple[0]), TemplateMap!(Mapper, Tuple[1 .. $])) TemplateMap;
	}
}

template Stringize(T) {
	enum Stringize = T.stringof;
}

template Stringize(alias sym) {
	enum Stringize = sym.stringof;
}
