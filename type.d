module adbi.type;

import std.stdio;
import std.traits;

/+abstract class DBType {
	
}

class DBType {
	TypeInfo nativeType;
	size_t size;
	
	static DBIntegralType byteType, ubyteType, intType, uintType;
	
	static this() {
		byteType = new DBIntegralType(typeid(byte), true);
	}
}

class DBIntegralType: DBNativeType {
	this(TypeInfo ti, bool signed) {
		super(ti);
		this.signed = signed;
	}
	
	bool signed;
}

class DBFloatType: DBNativeType {
	enum Precision {Float, Double, Real};
}

class DBArrayType: DBNativeType {
	size_t maxLength;
}

class DBStringType: DBArrayType {
	bool supportsI18N;
}+/