module adbi.traits;

public import std.traits;

template isInstanceDataMember(alias sym) {
	enum bool isInstanceDataMember = !isSomeFunction!sym && __traits(compiles, sym.offsetof);
}