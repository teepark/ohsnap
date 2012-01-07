-- one row for every photo
CREATE TABLE photo (
	id       INTEGER PRIMARY KEY,
	date TEXT NOT NULL,
	hash BLOB NOT NULL
);
CREATE UNIQUE INDEX photo_location on photo(hash, date);

-- one row for the original and each retouched version
CREATE TABLE photo_representation (
	photo    INTEGER NOT NULL,
	original INTEGER NOT NULL, --used as bool for original/retouched
	type     INTEGER NOT NULL,
	height   INTEGER NOT NULL,
	width    INTEGER NOT NULL,
	FOREIGN KEY(photo) REFERENCES photo(id)
);
-- TODO: is this index really needed?
CREATE INDEX repr_photo_orig on photo_representation(photo, original);

-- one row for every key/value pair in each photo's EXIF data
CREATE TABLE exif_info (
	photo INTEGER NOT NULL,
	key   BLOB NOT NULL,
	value BLOB,
	FOREIGN KEY(photo) REFERENCES photo(id)
);
CREATE INDEX exif_photo on exif_info(photo);
CREATE INDEX exif_key on exif_info(key);

-- a row for every unique tag
CREATE TABLE tag (
	id   INTEGER PRIMARY KEY,
	name TEXT NOT NULL
);
CREATE UNIQUE INDEX tag_name on tag(name);

-- join table for photo/tag; one per tag of a photo
CREATE TABLE photo_tag (
	photo INTEGER NOT NULL,
	tag   INTEGER NOT NULL,
	FOREIGN KEY(photo) REFERENCES photo(id),
	FOREIGN KEY(tag) REFERENCES tag(id)
);
CREATE INDEX phototag_photo on photo_tag(photo);
CREATE INDEX phototag_tag on photo_tag(tag);
