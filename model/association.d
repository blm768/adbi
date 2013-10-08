module adbi.model.association;

public import std.typecons;

mixin template hasOne(Association, string name, bool isNullable = true) {
	mixin(
		q{@property Association* } ~ name ~ q{() {
			static if(isNullable) {
				if(_association_id.isNull()) {
					return null;
				}
			}
			//Has the association been cached?
			if(!_association) {
				_association = new Association;
				*_association = Association.all.find(_association_id);
			}
			return _association;
		}}
	);

	mixin(
		q{@property void } ~ name ~ q{(Association* association) {
			static if(isNullable) {
				if(association == null) {
					_association_id.nullify();
					_association = null;
					return;
				}
			} else {
				assert(association);
			}
			_association_id = association.id;
			_association = association;
		}}
	);

	
	mixin(
		q{@Field @property auto } ~ name ~ q{_id() {
			//Try to update the ID from the association.
			if(_association) {
				if(_association.persisted) {
					_association_id = _association.id;
				} else {
					throw new Exception(`Association "` ~ name ~ `" has no ID.`);
				}
			}
			return _association_id;
		}}
	);
	
	mixin(
		q{@Field @property void } ~ name ~ q{_id(RecordID id) {
			//TODO: don't clear the cached association if the ID matches
			//the old one?
			_association = null;
			_association_id = id;
		}}
	);

	private:
	static if(isNullable) {
		Nullable!RecordID _association_id;
	} else {
		RecordID _association_id;
	}
	Association* _association;
}

mixin template belongsTo(Owner, string name, bool isNullable = false) {
	mixin hasOne!(Owner, name, isNullable);
}

