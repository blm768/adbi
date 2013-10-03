module adbi.model.traits;

public import adbi.traits;

template members(T) {
	alias TypeTuple!(__traits(allMembers, T)) members;
}

template isField(alias member) {
	enum bool isField = __traits(compiles, member.offsetof);
}

template isField(T, string memberName) {
	enum bool isField = mixin(`__traits(compiles, T.init.` ~ memberName ~ `.offsetof)`);
}

//TODO: use TemplateMap?
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
			alias name fields;
		} else {
			alias TypeTuple!() fields;
		}
	} else {
		alias TypeTuple!() fields;
	}
}

template fields(T, names ...) {
	alias TypeTuple!(fields!(T, names[0]), fields!(T, names[1 .. $])) fields;
}
