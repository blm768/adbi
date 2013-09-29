module adbi.model.traits;

public import std.traits;
import std.typetuple;

template members(T) {
	alias TypeTuple!(__traits(allMembers, T)) members;
}

template isField(alias member) {
	enum bool isField = __traits(compiles, member.offsetof);
}

template isField(T, memberName) {
	enum bool isField = isField!(__traits(getMember, T.init, memberName));
}

//TODO: fix or remove.
version(none) {
	template fields(T) {
		private alias TypeTuple!(__traits(allMembers, T)) members;
		static if(members.length == 0) {
			alias TypeTuple!() fields;
		} else {
			alias fields!(T, members) fields;
		}
	}

	template fields(T, string name) {
		static if(__traits(getProtection, __traits(getMember, T, name)) == "public") {
			static if(isField!(T, name)) {
				alias TypeTuple!(name) fields;
			} else {
				alias TypeTuple!() fields;
			}
		} else {
			alias TypeTuple!() fields;
		}
	}

	template instanceDataMembers(T, names ...) {
		alias TypeTuple!(fields!(T, names[0]), fields!(T, names[1 .. $])) fields;
	}
}
