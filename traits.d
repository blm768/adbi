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

template TemplateFilter(alias filter, Tuple ...) {
	static if(Tuple.length == 0) {
		alias TypeTuple!() TemplateFilter;
	} else {
		static if(filter!(Tuple[0])) {
			private alias Tuple[0] t;
		} else {
			private alias TypeTuple!() t;
		}
		alias TypeTuple!(t, TemplateFilter!(filter, Tuple[1 .. $])) TemplateFilter;
	}
}

template TemplateFind(alias filter, Tuple ...) {
	static if(Tuple.length == 0) {
		alias TypeTuple!() TemplateFind;
	} else {
		static if(filter!(Tuple[0])) {
			alias Tuple[0] TemplateFind;
		} else {
			alias TemplateFind!(filter, Tuple[1 .. $]) TemplateFind;
		}
	}
}

template stringize(T) {
	enum stringize = T.stringof;
}

template stringize(alias sym) {
	enum stringize = sym.stringof;
}

template sizeOf(T) {
	enum sizeOf = T.sizeof;
}
