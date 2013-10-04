module adbi.model.association;

mixin template belongsTo(Owner, string name) {
	mixin(
		"@property Owner " ~ name ~ "() {
			if(!_association_loaded) {
				_association = Owner.all.find(" ~ name ~ "_id);
				_association_loaded = true;
			}
			return _association;
		}"
	);

	mixin(
		"@property void " ~ name ~ "(Owner association) {
			_association_id = association.id;
			_association = association;
			_association_loaded = true;
		}"
	);


	mixin(
		"@Field @property RecordID " ~ name ~ "_id() {
			if(!_association.persisted) {
				throw new Error(`Association " ~ name ~ " not saved; cannot get ID`);
			}
			return _association_id;
		};"
	);

	mixin(
		"@Field @property void " ~ name ~ "_id(RecordID id) {
			if(id != _association_id) {
				_association_loaded = false;
			}
			_association_id = id;
		};"
	);

	private:
	RecordID _association_id;
	Owner _association;
	bool _association_loaded;
}
