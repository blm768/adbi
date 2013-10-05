module adbi.model.association;

mixin template hasOne(Association, string name) {
	mixin(
		"@property ref Association " ~ name ~ "() {
			if(!_association) {
				_association = new Association;
				*_association = Association.all.find(" ~ name ~ "_id);
			}
			return *_association;
		}"
	);

	mixin(
		"@property void " ~ name ~ "(Association association) {
			_association_id = association.id;
			_association = new Association;
			*_association = association;
		}"
	);


	mixin(
		"@Field @property RecordID " ~ name ~ "_id() {
			if(!(_association && _association.persisted)) {
				throw new Error(`Association " ~ name ~ " not saved; cannot get ID`);
			}
			return _association_id;
		};"
	);

	mixin(
		"@Field @property void " ~ name ~ "_id(RecordID id) {
			if(id != _association_id) {
				_association = null;
			}
			_association_id = id;
		};"
	);

	private:
	RecordID _association_id;
	Association* _association;
}

mixin template belongsTo(Owner, string name) {
	mixin hasOne!(Owner, name);
}
