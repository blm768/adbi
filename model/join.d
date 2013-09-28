module adbi.model.join;

/++
Represents a single result from a join operation
+/
struct Join(T ...) {
	mixin joinMembers!T;
	
	static Join fromQuery(Query q) {
		size_t index = 0;
		typeof(this) result;
		foreach(memberName; __traits(allMembers, Join)) {
			mixin("alias result." ~ memberName ~ " member;");
			static if(isInstanceDataMember!member) {
				auto ptr = &__traits(getMember, result, memberName);
				*ptr = typeof(*ptr).fromQuery(q, index);
				index += typeof(member).memberToColumn.length;
			}
		}
		return result;
	}
}

private template joinMembers(T ...) {
	static if(T.length > 0) {
		static if(T[0].stringof.length > 1) {
			mixin("T[0] " ~ toLower(T[0].stringof[0 .. 1]) ~ T[0].stringof[1 .. $] ~ ";");
		} else {
			mixin("T[0] " ~ toLower(T[0].stringof) ~ ";");
		}
		mixin joinMembers!(T[1 .. $]);
	}
}
