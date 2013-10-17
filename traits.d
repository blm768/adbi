module adbi.traits;

public import std.traits;
public import std.typetuple;

template TupleMap(alias Mapper, Tuple ...) {
	static if(Tuple.length == 0) {
		alias TypeTuple!() TupleMap;
	} else {
		alias TypeTuple!(Mapper!(Tuple[0]), TupleMap!(Mapper, Tuple[1 .. $])) TupleMap;
	}
}

template TupleFilter(alias filter, Tuple ...) {
	static if(Tuple.length == 0) {
		alias TypeTuple!() TupleFilter;
	} else {
		static if(filter!(Tuple[0])) {
			//Is the first member of the tuple a type?
			static if(is(Tuple[0])) {
				private alias Tuple[0] t;
			} else {
				private enum t = Tuple[0];
			}
		} else {
			private alias TypeTuple!() t;
		}
		alias TypeTuple!(t, TupleFilter!(filter, Tuple[1 .. $])) TupleFilter;
	}
}

template tupleContains(alias filter, Tuple ...) {
	static if(Tuple.length == 0) {
		enum tupleContains = false;
	} else {
		static if(filter!(Tuple[0])) {
			enum tupleContains = true;
		} else {
			enum tupleContains = tupleContains!(filter, Tuple[1 .. $]);
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

template memberNames(T) {
	alias TypeTuple!(__traits(allMembers, T)) memberNames;
}

template Attributes(alias sym) {
	alias TypeTuple!(__traits(getAttributes, sym)) Attributes;
}

template isNullable(T) {
	enum isNullable = false;
}

template isNullable(T: Nullable!T) {
	enum isNullable = true;
}
